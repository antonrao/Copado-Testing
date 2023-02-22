@isTest(IsParallel=false)
private class BatchGrantPermissionSetTest {
    public static Integer year = System.today().year() + 1;
    public static String CRON_EXP = '0 0 0 22 9 ? ' + year;

    @TestSetup
    static void setupTestData() {
        Id profileid = [select id from profile where Name = 'System Administrator'][0].id;
        PermissionSet ps = new PermissionSet(Name = 'Support_Community', Label = 'Support Community Access');
        insert ps;
        PermissionSetGroup psg = new PermissionSetGroup(DeveloperName = 'Test_Group', MasterLabel = 'Test Group');
        insert psg;

        List<User> users = new List<User>();
        String userprefix = UserInfo.getOrganizationId() + System.now().millisecond();
        for (Integer i =0; i < 10; i++) {
            User u = new User(Username=userprefix + 'admin' + i + '@example.com', Email='admin@example.com');
            u.FirstName = 'First';
            u.LastName = 'Last';
            u.Alias = 'Alias';
            u.TimeZoneSidKey = 'America/New_York';
            u.LocaleSidKey = 'en_US';
            u.EmailEncodingKey = 'ISO-8859-1';
            u.ProfileId = profileid;
            u.LanguageLocaleKey = 'en_US';
            users.add(u);
        }
        insert users;
    }

    @isTest
    static void it_should_assign_permissionset() {
        Test.startTest();
        BatchGrantPermissionSet b = new BatchGrantPermissionSet('System Administrator', 'Support_Community');
        Id batchId = Database.executeBatch(b);
        Test.stopTest();

        //then - test sys admin users should have the permission set
        List<PermissionSetAssignment> psa = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId IN(SELECT Id FROM User WHERE Email = 'admin@example.com')
            AND PermissionSet.Name = 'Support_Community'
        ];
        System.assertEquals(10, psa.size(), 'Permission set should be assigned to the user.');
    }

    @isTest
    static void it_should_assign_permissionsetgroup() {
        Test.startTest();
        BatchGrantPermissionSet.schedule('System Administrator', 'Test_Group');
        Test.stopTest();

        //then - test sys admin users should have the permission set
        List<PermissionSetAssignment> psa = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId IN(SELECT Id FROM User WHERE Email = 'admin@example.com')
            AND PermissionSetGroup.DeveloperName = 'Test_Group'
        ];
        System.assertEquals(10, psa.size(), 'Permission set should be assigned to the user.');
    }

    @isTest
    static void it_should_add_filter() {
        User adminUser = [SELECT Username FROM User WHERE Email = 'admin@example.com' LIMIT 1];
        Test.startTest();
        BatchGrantPermissionSet b = new BatchGrantPermissionSet('System Administrator', 'Support_Community', 'Id = \'' + adminUser.Id + '\'');
        Id batchId = Database.executeBatch(b);
        Test.stopTest();

        //then - test sys admin users should have the permission set
        List<PermissionSetAssignment> psa = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId IN(SELECT Id FROM User WHERE Email = 'admin@example.com')
            AND PermissionSet.Name = 'Support_Community'
        ];
        System.assertEquals(1, psa.size(), 'Permission set should be assigned to the user.');
    }

    @isTest
    static void it_should_throw_error_when_perm_set_is_fake() {
        QueryException caught;
        try {
            new BatchGrantPermissionSet('System Administrator', 'Never Going to be Real');
        } catch (QueryException ex) {
            caught = ex;
        }
        System.assertNotEquals(null, caught);
    }
}