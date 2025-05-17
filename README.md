# OneDrive Sync Add-on Repository

This repository contains the **OneDrive Sync** add-on for Home Assistant.

## Add-on

- **Slug:** onedrive_sync
- **Version:** 1.1.2
- **Description:** Bidirectional sync between Home Assistant folder and Microsoft OneDrive sub-folder.

## Usage

1. Add this repository to your Home Assistant Supervisor:
   - URL: https://github.com/yourrepo/onedrive-sync-addon
2. Install the *OneDrive Sync* add-on.
3. Configure options (local_folder, remote_folder, azure_client_id, azure_client_secret) in the add-on UI.
4. Start the add-on.

## Development

- Build:
  ```bash
  docker build --tag local/onedrive_sync .
  ```
- Run:
  ```bash
  docker run -v /path/to/data:/data -v /path/to/media:/media local/onedrive_sync
  ```

## Files

- `repository.yaml`: Repository metadata.
- `LICENSE`: MIT License.
- `my_addon/`: Add-on folder.
  - `config.yaml`: Add-on configuration.
  - `Dockerfile`: Docker build file.
  - `run.sh`: Entrypoint script.
  - `CHANGELOG.md`: Release notes.
  - `DOCS.md`: Additional documentation.
  - `logo.png`: Add-on logo.
