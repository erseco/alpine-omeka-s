#!/usr/bin/env php
<?php
/**
 * CLI CSV importer for Omeka S using CSVImport module.
 *
 * This script mirrors what the admin UI does:
 *  - Boots Omeka S
 *  - Loads CSVImport module services
 *  - Sets an authenticated user in AuthenticationService (so Jobs get an owner)
 *  - Builds args including "column" from CSV headers
 *  - Dispatches CSVImport\Job\Import synchronously/by default strategy
 *
 * Usage:
 *   php import_cli.php /absolute/path/to/file.csv [--email=admin@example.com] [--owner-id=1]
 *
 * Env fallback:
 *   OMEKA_ADMIN_EMAIL can be used instead of --email
 */

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "This script can only be run from CLI.\n");
    exit(1);
}

// ---------- Parse CLI args ----------
$cliFile = $argv[1] ?? null;
if (!$cliFile || !is_readable($cliFile)) {
    fwrite(STDERR, "Usage: php " . basename(__FILE__) . " /path/to/file.csv [--email=EMAIL] [--owner-id=ID]\n");
    exit(1);
}

// Get the absolute, canonical path to the source file.
$originalFilepath = realpath($cliFile);
if ($originalFilepath === false) {
    fwrite(STDERR, "ERROR: The file path '$cliFile' could not be resolved or does not exist.\n");
    exit(1);
}

// Optional flags.
$emailArg = null;
$ownerIdArg = null;
foreach ($argv as $arg) {
    if (strpos($arg, '--email=') === 0) {
        $emailArg = substr($arg, 8);
    } elseif (strpos($arg, '--owner-id=') === 0) {
        $ownerIdArg = (int) substr($arg, 11);
    }
}
if (!$emailArg && getenv('OMEKA_ADMIN_EMAIL')) {
    $emailArg = getenv('OMEKA_ADMIN_EMAIL');
}

// ---------- Bootstrap Omeka ----------
chdir(__DIR__);
require __DIR__ . '/bootstrap.php';
/** @var Laminas\Mvc\Application $application */
$application = Laminas\Mvc\Application::init(require __DIR__ . '/application/config/application.config.php');
$services = $application->getServiceManager();

// ---------- Load CSVImport module (register plugins/services) ----------
try {
    $moduleManager = $services->get('ModuleManager');
    $moduleManager->loadModule('CSVImport');
    echo "CSVImport module loaded.\n";
} catch (\Throwable $e) {
    fwrite(STDERR, "FATAL: CSVImport module not available/enabled. " . $e->getMessage() . "\n");
    exit(1);
}

// ---------- Resolve user to act as (so the Job has an owner) ----------
/**
 * Strategy:
 *  1) If --owner-id is provided, use that.
 *  2) Else, if --email or OMEKA_ADMIN_EMAIL is provided, look up user by email.
 *  3) Else, fallback to user id 1 (common first admin).
 *
 * Then write the identity into Omeka\AuthenticationService storage so Dispatcher sees it.
 */
$entityManager = $services->get('Omeka\EntityManager');
$api = $services->get('Omeka\ApiManager');
$auth = $services->get('Omeka\AuthenticationService');

$userEntity = null;

if ($ownerIdArg) {
    $userEntity = $entityManager->find(\Omeka\Entity\User::class, $ownerIdArg);
} elseif ($emailArg) {
    try {
        $resp = $api->search('users', ['email' => $emailArg]);
        $users = $resp->getContent();
        if ($users) {
            $userEntity = $entityManager->find(\Omeka\Entity\User::class, $users[0]->id());
        }
    } catch (\Throwable $e) {
        // ignore, will try id=1
    }
}
if (!$userEntity) {
    $userEntity = $entityManager->find(\Omeka\Entity\User::class, 1);
}
if (!$userEntity) {
    fwrite(STDERR, "ERROR: Unable to resolve a user to own the job. Provide --owner-id or --email.\n");
    exit(1);
}

// Set the "logged-in" user for this CLI process.
$auth->getStorage()->write($userEntity);
echo "Acting as user: {$userEntity->getEmail()} (id {$userEntity->getId()})\n";


// ---------- Configure URL/Path helpers for CLI environment ----------
// This is crucial to prevent warnings and errors when Omeka tries to build
// full URLs during the job execution (e.g., in log messages).
echo "Configuring URL helpers for CLI...\n";
$viewHelperManager = $services->get('ViewHelperManager');

// You should set these to match your Omeka S installation's public URL.
// Using environment variables is the most flexible approach.
$serverUrl = getenv('OMEKA_SERVER_URL') ?: 'http://localhost:8080';
$basePath = getenv('OMEKA_BASE_PATH') ?: '/';

try {
    // Configure BasePath helper
    $viewHelperManager->get('BasePath')->setBasePath($basePath);
    echo "BasePath set to: $basePath\n";

    // Configure ServerUrl helper
    $serverUrlHelper = $viewHelperManager->get('ServerUrl');
    $urlParts = parse_url($serverUrl);
    if ($urlParts === false) {
        throw new \Exception("Invalid OMEKA_SERVER_URL: $serverUrl");
    }

    $scheme = $urlParts['scheme'] ?? 'http';
    $host = $urlParts['host'] ?? 'localhost';
    $port = $urlParts['port'] ?? null;
    
    $serverUrlHelper->setScheme($scheme);
    $serverUrlHelper->setHost($host);
    if ($port) {
        $serverUrlHelper->setPort($port);
    }
    echo "ServerUrl set to: $scheme://$host" . ($port ? ":$port" : "") . "\n";

} catch (\Throwable $e) {
    fwrite(STDERR, "WARNING: Could not configure URL helpers. This may cause issues. " . $e->getMessage() . "\n");
    // Continue execution, as it might still work for simple imports.
}

// ---------- Create a temporary copy of the import file ----------
// The CSVImport module is designed to DELETE the source file after import,
// assuming it's a temporary upload. To prevent it from deleting our master data file,
// we create a temporary copy and pass that to the job.

$tempFilepath = tempnam(sys_get_temp_dir(), 'omeka_import_');
if ($tempFilepath === false) {
    fwrite(STDERR, "ERROR: Could not create a temporary file in " . sys_get_temp_dir() . ".\n");
    exit(1);
}
// Now, copy the original file's content to the temporary file.
if (!copy($originalFilepath, $tempFilepath)) {
    fwrite(STDERR, "ERROR: Could not copy '$originalFilepath' to temporary file '$tempFilepath'.\n");
    @unlink($tempFilepath); // Clean up the empty temp file.
    exit(1);
}
echo "Created temporary copy for import: $tempFilepath\n";

// ---------- Build args similar to the controller flow ----------

// Detect media type like controller does.
$mediaType = (new finfo(FILEINFO_MIME_TYPE))->file($tempFilepath);
if ($mediaType === 'text/plain' || $mediaType === 'text/html') {
    $ext = strtolower(pathinfo($tempFilepath, PATHINFO_EXTENSION));
    $map = [
        'csv' => 'text/csv',
        'tab' => 'text/tab-separated-values',
        'tsv' => 'text/tab-separated-values',
    ];
    if (isset($map[$ext])) {
        $mediaType = $map[$ext];
    }
}

// Compute headers for args['column'] (first row).
$headers = [];
if (($fh = fopen($tempFilepath, 'r')) !== false) {
    $headers = fgetcsv($fh, 0, ',','"','\\');
    fclose($fh);
}
if (!$headers || !is_array($headers)) {
    fwrite(STDERR, "ERROR: CSV appears to have no header row.\n");
    exit(1);
}

// Prepare args consistent with UI mapping step.
$args = [
    'filename' => basename($originalFilepath), // Use original filename for logs.
    'filesize' => (string) filesize($tempFilepath),
    'filepath' => $tempFilepath, // CRITICAL: Pass the temporary file path to the job.
    'media_type' => $mediaType,
    'resource_type' => 'items',
    'comment' => 'CLI import with media ' . date('Y-m-d H:i:s'),
    'automap_check_names_alone' => false,

    // Column headers as seen by the module.
    'column' => $headers,

    // Example property mapping (matches your sample and controller cleanArgs result).
    // Keys are column indexes; values are property term => property id (int).
    'column-property' => [
        0 => ['dcterms:title' => 1],
        1 => ['dcterms:creator' => 2],
        2 => ['dcterms:description' => 4],
    ],

    // Map the media column.
    // We tell the module: "The column at index 3 contains a source
    // that should be processed by the 'url' ingester."
    'column-media_source' => [
        3 => 'url', // Index 3 corresponds to the 'media_url' column.
    ],
    // NOTE: We don't need to map the 'media_source' column (index 4),
    // because the 'url' ingester is already specified here. The module does not use
    // a column to read the ingester name, you configure it here in the mapping.

    'o:resource_template' => '',
    'o:resource_class' => '',
    'o:owner' => ['o:id' => $userEntity->getId()],
    'o:is_public' => 1,

    'multivalue_separator' => ',',
    'global_language' => '',

    'action' => 'update',      
    'identifier_column' => 0,   // "dcterms:title" column
    'identifier_property' => 'dcterms:title',
    'action_unidentified' => 'create',
    'rows_by_batch' => 20,

    'column-multivalue' => [],
    'delimiter' => ',',
    'enclosure' => '"',
    'escape' => '\\',
];

// ---------- Dispatch the job ----------
try {
    /** @var Omeka\Job\Dispatcher $dispatcher */
    $dispatcher = $services->get('Omeka\Job\Dispatcher');

    // Let Omeka choose the default strategy (Synchronous by default here).
    $job = $dispatcher->dispatch('CSVImport\\Job\\Import', $args);

    echo "Dispatched CSVImport job id: " . $job->getId() . "\n";
    echo "Check progress in Admin > Jobs.\n";
} catch (\Throwable $e) {
    fwrite(STDERR, "ERROR: Failed to dispatch CSV import job: " . $e->getMessage() . "\n");
    exit(1);
}

exit(0);
