/**
 *	Assigns a permission set or permission set group to all user with the specified profile.
 *   Additional filter criteria can be passed in if the users needs filtered further.
 *   Example: Only assign permission set to community users on the Salesforce account 
 *            String filter = 'Contact.Account.Name = \'Salesforce\'';
 *            BatchGrantPermissionSet('Community User Profile', 'Salesforce_Account_Privs', filter);
 */
public class BatchGrantPermissionSet implements Database.Batchable<sObject> {
    String query {get; set;}

    Profile targetProfile {get; set;}
    PermissionSet targetPermSet {get; set;}
    PermissionSetGroup targetPermSetGroup {get; set;}

    Id targetProfileId { get { return targetProfile.Id; } }
    Id targetPermSetId { get { return targetPermSet.Id; } }
    Id targetPermSetGroupId { get { return targetPermSetGroup.Id; } }

    public static void schedule(String profileName, String permSetName) {
        BatchGrantPermissionSet batch = new BatchGrantPermissionSet(profileName, permSetName);
        Database.executeBatch(batch, 200);
    }

    public BatchGrantPermissionSet(String profileName, String permSetName) {
        if (String.isBlank(profileName)) {
            throw new HandledException('profileName is required');
        }
        if (String.isBlank(permSetName)) {
            throw new HandledException('permSetName is required');
        }
        this.query = 'SELECT Id FROM User ' +
            ' WHERE IsActive = true AND ProfileId = :targetProfileId ';

        this.targetProfile = [SELECT Id, Name FROM Profile WHERE Name = :profileName];
        PermissionSet[] permSets = [SELECT Id, Name FROM PermissionSet WHERE Name = :permSetName];
        if (permSets.size() > 0) {
            this.targetPermSet = permSets[0];
            this.query += ' AND Id NOT IN (SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetId = :targetPermSetId)';
        } else {
            this.targetPermSetGroup = [SELECT Id, DeveloperName FROM PermissionSetGroup WHERE DeveloperName = :permSetName];
            this.query += ' AND Id NOT IN (SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetGroupId = :targetPermSetGroupId)';
        }
    }

    public BatchGrantPermissionSet(String targetProfileName, String permSetName, String filter) {
        this(targetProfileName, permSetName);
        //Build out user query
        this.query += 'AND (' + filter + ')';
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();

        for (User u : (List<User>)scope) {
            PermissionSetAssignment psa = new PermissionSetAssignment(
                AssigneeId = u.Id
            );
            if (targetPermSet != null) {
                psa.PermissionSetId = targetPermSet.Id;
            } else {
                psa.PermissionSetGroupId = targetPermSetGroup.Id;
            }
            psaList.add(psa);
        }

        //Insert Permission Set Assignments
        if (psaList.size() > 0) {
            insert psaList;
        }
    }

    public void finish(Database.BatchableContext BC) {
    }
}