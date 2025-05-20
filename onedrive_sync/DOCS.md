# Documentation

This document provides additional details about the OneDrive Sync add-on.

## Configuration

The add-on options are defined in `config.yaml` and include:

- `local_folder` (string, required): Local directory to sync.
- `remote_folder` (string, optional): OneDrive sub-folder name.
- `azure_client_id` (string, optional): Azure App client ID.
- `azure_client_secret` (string, optional): Azure App client secret.

For more information on setting up Azure authentication, see the official documentation:
https://github.com/abraunegg/onedrive/blob/master/docs/oauth.md
