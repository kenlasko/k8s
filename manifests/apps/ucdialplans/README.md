# Introduction
UCDialplans is my website that allows users to automatically create Teams dialplans for any country in the world. The image is built using Mono and is hosted locally on the internal image registry and on a private Docker repository.

It is accessible to the world via my ~~[Cloudflare Tunnel](/manifests/network/cloudflare)~~ Oracle Cloud-based [Pangolin](https://github.com/kenlasko/pangolin) deployment.

Most configuration is done via my [custom Helm chart](/helm/baseline).

# Prerequisites
## Database
* Requires access to `ucdialplans` database on MariaDB via `UCDialplans_Website` user account. 
* Requires [InfoCache_Update](/manifests/database/mariadb/procedures.sql) procedure for periodically updating website usage numbers. 

# Disaster Recovery
Should the home cluster become unavailable for an extended period, UCDialplans.com can be switched to use my Oracle Cloud-based cluster. [MariaDB](/manifests/database/mariadb) is continuously backed up from on-prem, so a switch should be relatively easy. 

## Pangolin
Very simple process:
1. Login to [Pangolin](https://pangolin.ucdialplans.com)
2. On the left side, select `Resources` and click on `Edit` beside `UCDialplans Website`
3. Under `Targets List`, change the `Site` from `K8S Home` to `K8S Cloud` and then click on `Save Settings`

## Cloudflare Tunnel (Deprecated)
The only thing required is to switch the FQDNs for the Cloudflare Tunnel so that the Cloud tunnel is set to use www.ucdialplans.com and on-prem is switched to www2.ucdialplans.com.

1. Log onto https://dash.cloudflare.com/
2. Navigate to **Zero Trust**
3. Navigate to **Networks** - **Tunnels**
4. Edit the **20 Spring** tunnel 
5. Click on **Public hostname** and edit **www.ucdialplans.com**
6. Change the subdomain to **www3** and save
7. Edit the **20 Spring DR** tunnel and repeat the same steps, except change the subdomain from **www2** to **wwww**.
8. Save and exit

When the main cluster comes back online, simply reverse the steps when ready.

## Useful MariaDB SQL queries
### Add user donation
```
set @UserID = '123123123123123123' COLLATE utf8mb4_general_ci;
set @DonationAmount = 10 COLLATE utf8mb4_general_ci;

UPDATE Users SET Donation = IFNULL((SELECT Donation FROM Users WHERE UserID = @UserID),0) + @DonationAmount, LastDonation = CURDATE(), DonationCount = IFNULL((SELECT DonationCount FROM Users WHERE UserID = @UserID),0) + 1 WHERE UserID = @UserID;
```

### Check for email updates
```
SELECT Rulesets.ID, Rulesets.CountryID, Rulesets.Date, Rulesets.GWType, Rulesets.NPA, Rulesets.NXX,
Rulesets.City, Rulesets.StateProv, Rulesets.CustomRule, Rulesets.SIPTrunk, Rulesets.SevenDigitRules, 
Rulesets.ExtAccessNum, Rulesets.BlockCallIDCode, Rulesets.BlockCallIDRepl, Rulesets.Email, 
CAST(UNCOMPRESS(Rulesets.Ruleset) AS VARCHAR(400000)) AS UserRuleset, CAST(UNCOMPRESS(PrefixList.Ruleset) AS VARCHAR(400000)) AS PrefixRuleset, CAST(UNCOMPRESS(PrefixList.XMLData) AS VARCHAR(400000)) AS XMLData 
FROM Rulesets Rulesets 
JOIN NANPA_Prefix PrefixList ON PrefixList.Prefix = CONCAT(Rulesets.NPA,Rulesets.NXX) 
WHERE (Rulesets.Email <> '' AND Rulesets.Ruleset IS NOT NULL AND SimpleRules = 0 AND (DateDiff(CURDATE(),Rulesets.Date) > 60 AND (DateDiff(CURDATE(),Rulesets.LastUpdate) > 60 OR Rulesets.LastUpdate IS NULL))) AND (Rulesets.Ruleset <> PrefixList.Ruleset OR Rulesets.Ruleset IS NULL OR PrefixList.Ruleset IS NULL OR DateDiff(CURDATE(), PrefixList.LastUpdate) > 60) 
ORDER BY PrefixList.LastUpdate, Rulesets.LastUpdate ASC LIMIT 25;
```

### Find user by name/email
```
SET @namesearch = 'jansen' COLLATE utf8mb4_general_ci;

SELECT Users.UserID, Users.FirstName, Users.LastName, Users.EmailAddress, Users.DonationCount, Users.Donation, Users.LastDonation as LastDonation, Count(*) AS Frequency, MAX(Rulesets.Date) AS LastUsed FROM Rulesets 
INNER JOIN Users ON Rulesets.UserID = Users.UserID
WHERE EmailAddress LIKE CONCAT('%', @namesearch, '%') OR LastName LIKE CONCAT('%', @namesearch, '%') OR FirstName LIKE CONCAT('%', @namesearch, '%')
GROUP BY Users.UserID, Users.FirstName, Users.LastName, Users.EmailAddress, Users.DonationCount, Users.LastDonation, Users.Donation
ORDER BY Frequency DESC;
```

# Delete email from all rulesets
```
UPDATE `Rulesets`
SET Email = ''
WHERE Email = 'Turd.Ferguson@contoso.com'
```