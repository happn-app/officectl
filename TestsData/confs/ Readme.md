#  Confs for tests

This folder must contain valid confs for the tests to pass.
For obvious reasons, the private confs are not in git.

## happn
The file `happn.json` is expected with the following template:
```json
{
   "service_name": "happn",
   "connector_settings": {
      "base_url": "test-api-url",
      "client_id": "test-client-id",
      "client_secret": "test-client-secret",
      "admin_username": "test-admin-username",
      "admin_password": "test-admin-password"
   },
   "user_id_builders": [
      ...
   ],
   "domain_aliases": {
      ...
   }
}
```

## google
The file `google.json` is expected with the following template:
```json
{
   "service_name": "gougle",
   "primary_domains": [
      ...
   ],
   "connector_settings": {
      "admin_email": "test-admin-email",
      "superuser_json_creds_path": "path-to-service-account",
   },
   "user_id_builders": [
   ]
}
```
