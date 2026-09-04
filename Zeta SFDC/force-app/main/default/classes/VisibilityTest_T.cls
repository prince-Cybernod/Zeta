@IsTest
private class VisibilityTest_T {
    @IsTest
    static void testVisibility() {
        List<PartyRoleRelation> prrs = [SELECT Id, Name FROM PartyRoleRelation];
        System.debug('PRR count: ' + prrs.size());
        for(PartyRoleRelation prr : prrs) {
            System.debug('PRR: ' + prr.Name);
        }
    }
}