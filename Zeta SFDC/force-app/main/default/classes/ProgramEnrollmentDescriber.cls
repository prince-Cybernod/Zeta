public inherited sharing class ProgramEnrollmentDescriber {
    /**
     * Search term to filter SObjects by name or label. Defaults to 'program'.
     */
    public String searchTerm { get; set; }

    /**
     * Matching objects found by describe, keyed by API name with value as the object's label.
     */
    public Map<String, String> matchingObjects { get; private set; }

    /**
     * Controller constructor. Initializes default search and performs describe.
     */
    public ProgramEnrollmentDescriber() {
        this.searchTerm = 'programEnrollment';
        System.debug(LoggingLevel.INFO, 'ProgramEnrollmentDescriber constructed. Page URL=' + (ApexPages.currentPage() != null ? ApexPages.currentPage().getUrl() : 'null') + ', searchTerm=' + this.searchTerm);
        describeAndFilter();
    }

    /**
     * Action method to re-run the describe search (useful if page changes searchTerm).
     */
    public PageReference doSearch() {
        System.debug(LoggingLevel.INFO, 'ProgramEnrollmentDescriber.doSearch invoked. Page URL=' + (ApexPages.currentPage() != null ? ApexPages.currentPage().getUrl() : 'null') + ', searchTerm=' + this.searchTerm);
        describeAndFilter();
        return null;
    }

    /**
     * Performs the global describe and filters objects by the search term.
     * Applies basic access controls (isAccessible and isCreateable) before including results.
     */
    private void describeAndFilter() {
        matchingObjects = new Map<String, String>();

        if (String.isBlank(searchTerm)) {
            return;
        }

        String searchTermLower = searchTerm.toLowerCase();

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        for (String objectName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult describeResult = globalDescribe.get(objectName).getDescribe();

            // Skip objects that aren't accessible or createable
            if (!describeResult.isAccessible() || !describeResult.isCreateable()) {
                continue;
            }

            String label = describeResult.getLabel();

            // Check if the object name or label contains the search term (case-insensitive)
            Boolean nameMatches = (objectName != null && objectName.toLowerCase().contains(searchTermLower));
            Boolean labelMatches = (label != null && label.toLowerCase().contains(searchTermLower));

            if (nameMatches || labelMatches) {
                // Store API name → Label in the results
              System.debug('describeResult.getName()=' + describeResult.getName());
                matchingObjects.put(describeResult.getName(), label);
            }
        }
        System.debug(LoggingLevel.INFO, 'ProgramEnrollmentDescriber.describeAndFilter complete. searchTerm=' + searchTerm + ', matchCount=' + matchingObjects.size());
    }

    /**
     * Convenience getter for Visualforce to render results as a sorted list of strings.
     * Each entry is formatted as `APIName — Label`.
     */
    public List<String> getMatches() {
        List<String> rows = new List<String>();
        if (matchingObjects == null) {
            return rows;
        }
        for (String apiName : matchingObjects.keySet()) {
            rows.add(apiName + ' — ' + matchingObjects.get(apiName));
        }
        rows.sort();
        return rows;
    }
}