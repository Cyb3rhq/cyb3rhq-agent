#!/bin/sh

## Stop and remove application
sudo /Library/Ossec/bin/cyb3rhq-control stop
sudo /bin/rm -r /Library/Ossec*

# remove launchdaemons
/bin/rm -f /Library/LaunchDaemons/com.cyb3rhq.agent.plist

## remove StartupItems
/bin/rm -rf /Library/StartupItems/CYB3RHQ

## Remove User and Groups
/usr/bin/dscl . -delete "/Users/cyb3rhq"
/usr/bin/dscl . -delete "/Groups/cyb3rhq"

/usr/sbin/pkgutil --forget com.cyb3rhq.pkg.cyb3rhq-agent
/usr/sbin/pkgutil --forget com.cyb3rhq.pkg.cyb3rhq-agent-etc

# In case it was installed via Puppet pkgdmg provider

if [ -e /var/db/.puppet_pkgdmg_installed_cyb3rhq-agent ]; then
    rm -f /var/db/.puppet_pkgdmg_installed_cyb3rhq-agent
fi

echo
echo "Cyb3rhq agent correctly removed from the system."
echo

exit 0
