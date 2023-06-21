# Webtrees Manager

This is a Python script that helps with setting up and managing a new Webtrees instance on Ubuntu-Server.
Current features are:

- install and setup complete LAMP Stack
  - Apache Webserver
  - PHP
  - MariaDB
  - Uncomplicated Firewall
- install and setup Webtrees
- SSL certificate provisioning and renewal with Certbot
- local backup initialisation and automation with Borgbackup

## Quickstart

1. Have a fresh Ubuntu-Server install with Shell access
2. Domain name with DNS record pointed at the server
3. Run this command to start the script (`git` and/or `script` might be missing if the command fails):

```bash
git clone https://github.com/Tuetenk0pp/webtrees-mngr.git && cd ~/webtrees-mngr/ && chmod +x webtrees-mngr.py && sudo ./webtrees-mngr.py
```

4. Provide details and select options as the script runs
5. Visit your domain and enjoy your new webtrees install

## Contributions

Have a look at the [Issues Tab](https://github.com/Tuetenk0pp/webtrees-mngr/issues) to find out how you can help.
Submit a PR only if you tested your changes already.

## License

[MIT License](./LICENSE.md)
