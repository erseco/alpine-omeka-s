#!/usr/bin/env php
<?php
/**
 * Command-Line Interface (CLI) script to run a CSVImport job in Omeka S.
 *
 * USAGE:
 *   php import_cli.php /path/to/your/file.csv
 *
 * IMPORTANT:
 * This script assumes a FIXED mapping configuration. You must edit the
 * "Import Configuration" section below to match your CSV's structure
 * and your desired mappings.
 */

// --- CLI Check ---
if (PHP_SAPI !== 'cli') {
    echo "This script can only be run from the command line.\n";
    exit(1);
}

// --- Command-Line Argument Check ---
if ($argc < 2) {
    echo "Error: You must provide the full path to the CSV file as the first argument.\n";
    echo "Usage: php " . basename(__FILE__) . " /path/to/your/file.csv\n";
    exit(1);
}

$csvFilePath = $argv[1];
if (!file_exists($csvFilePath) || !is_readable($csvFilePath)) {
    echo "Error: The file '$csvFilePath' does not exist or cannot be read.\n";
    exit(1);
}

// --- Bootstrap Omeka S Application ---
// This loads the entire Omeka S environment so we can use its services.
// The __DIR__ constant ensures paths are relative to this script's location.
require __DIR__ . '/bootstrap.php';
$application = Laminas\Mvc\Application::init(require __DIR__ . '/application/config/application.config.php');
$serviceLocator = $application->getServiceManager();

echo "Omeka S environment loaded successfully.\n";

// --- Load the CSVImport Module's Autoloader ---
// THIS IS THE CRITICAL FIX: Manually include the module's own dependencies.
$csvImportAutoloader = __DIR__ . '/modules/CSVImport/vendor/autoload.php';
if (!file_exists($csvImportAutoloader)) {
    echo "Error: CSVImport module autoloader not found at '$csvImportAutoloader'.\n";
    echo "Please ensure the CSVImport module is installed and you have run 'composer install' within its directory if you installed from source.\n";
    exit(1);
}
require_once $csvImportAutoloader;

// --- Import Configuration ---
// THIS IS THE MOST IMPORTANT PART TO CUSTOMIZE.
// This array simulates the data that would be submitted from the web form.
// You must adjust it to your specific needs.

// This example is based on the Mona Lisa CSV from the previous question.
$args = [
    // --- Basic file arguments ---
    'filepath' => $csvFilePath,
    'media_type' => 'text/csv', // or 'text/tab-separated-values', 'application/vnd.oasis.opendocument.spreadsheet'

    // --- Import Settings (from the first tab in the UI) ---
    'resource_type' => 'items', // Can be 'items', 'item_sets', 'media', 'users', 'resources'
    'delimiter' => ',',
    'enclosure' => '"',
    'automap_check_names_alone' => true, // Replicates the "Automap with simple labels" checkbox
    'comment' => 'Automatic import from CLI on ' . date('Y-m-d H:i:s'),

    // --- Column Mapping (from the "Map to Omeka S data" tab) ---
    // This is the most complex part. The key is the column index (starting from 0).
    // For vocabulary properties (like dcterms):
    'column-property' => [
        0 => ['dcterms:title' => 10], // Column 0 -> dcterms:title. The ID (10) is a placeholder, the term is what matters.
        1 => ['dcterms:description' => 4], // Column 1 -> dcterms:description
        2 => ['dcterms:creator' => 3], // Column 2 -> dcterms:creator
        3 => ['dcterms:date' => 5], // Column 3 -> dcterms:date
        4 => ['dcterms:source' => 11], // Column 4 -> dcterms:source
        // Mapping the MEDIA's TITLE
        6 => ['dcterms:title' => 10], // Column 6 (media_title) -> dcterms:title of the media object
    ],

    // For media sources:
    'column-media_source' => [
        5 => 'url' // Column 5 (media_url) is mapped as a URL source type
    ],

    // To indicate which columns use the multivalue separator:
    'column-multivalue' => [
        2 => '1' // Column 2 (creator) uses the multivalue separator.
    ],

    // --- Basic Settings (from the "Basic Settings" tab) ---
    'multivalue_separator' => ';', // The character that separates multiple values in a single cell
    // 'o:resource_template' => ['o:id' => 1], // (Optional) ID of the resource template to use
    // 'o:owner' => ['o:id' => 1], // (Optional) ID of the user owner. If not set, it will default to the super user.
    'o:is_public' => true, // Visibility of the created items
    // 'o:item_set' => [['o:id' => 2], ['o:id' => 3]], // (Optional) Array of item set IDs to add the items to

    // --- Advanced Settings (from the "Advanced Settings" tab) ---
    'action' => 'create', // can be 'create', 'update', 'append', 'replace', 'delete'
    // If action is 'update', 'append', etc., you will need these:
    // 'identifier_column' => 0, // The column index containing the identifier (e.g., Title)
    // 'identifier_property' => 'dcterms:title', // The property that contains the identifier
    // 'action_unidentified' => 'skip', // 'skip' or 'create'

    'rows_by_batch' => 20, // Number of rows to process per batch
];

// --- Dispatch the Job ---
try {
    echo "Attempting to dispatch the import job...\n";
    
    // Get the Job Dispatcher service
    $jobDispatcher = $serviceLocator->get('Omeka\Job\Dispatcher');
    
    // Dispatch the specific CSVImport job with our arguments
    $job = $jobDispatcher->dispatch('CSVImport\Job\Import', $args);
    
    echo "Success! Import job dispatched with ID: " . $job->getId() . "\n";
    echo "You can monitor its progress in the Omeka S admin dashboard under the 'Jobs' section.\n";

} catch (Exception $e) {
    echo "Error dispatching the job: " . $e->getMessage() . "\n";
    exit(1);
}

exit(0);