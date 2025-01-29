# README


## Table of Contents

* [Introduction](#introduction)
* [Features](#features)
* [Getting Started](#getting-started)

## Introduction
This repo is created to keep my self-hosted various services dockerfiles.

## Getting Started
Welcome to My Self-Hosted Services Repository!

This repository contains Dockerfiles for various services that I use on my self-hosted local machine. The goal of this project is to provide a centralized and version-controlled collection of these configurations, making it easier to manage and maintain them.

### Features

* **Dockerized Services**: This repository includes Dockerfiles for various services such as [insert service names here], allowing me to easily containerize and deploy them on my local machine.
* **Version Control**: By storing the Dockerfiles in this repository, I can keep track of changes and updates made to each service over time.

### Getting Started

To get started with using these Dockerfiles, follow these steps:

1. Clone this repository to your local machine.
2. Update the `docker-compose.yml` file to reflect any changes you've made to the services or their configurations.
3. Run `docker-compose up -d` to start the service in detached mode.
4. `docker-compose down` to bring down the service that's already running.

### Services

* **Security**
  * [Adguard Home](docker_compose/adguard/) - Block ads, malware, and spyware
  * [Caddy](docker_compose/caddy/) - Reverse proxy for local services
  * [Nginx](docker_compose/nginx/) - Reverse proxy server for routing traffic to appropriate local services

* **Media**
  * [Plex Media Server](docker_compose/plex/) - Media streaming for movies, music, and photos
  * [Deluge](docker_compose/deluge/) - Torrent client for media downloads

* **Productivity**
  * [Nextcloud](docker_compose/nextcloud/) - Self-hosted cloud storage & collaboration
  * [FreshRSS](docker_compose/freshrss/) - RSS feed reader
  * [Mealie](docker_compose/mealie/) - Recipe manager for meal planning

* **Automation & Monitoring**
  * [Home Assistant](docker_compose/home-assistant/) - Open-source home automation
  * [Homarr](docker_compose/homarr/) - Stream monitoring and management
  * [Portainer](docker_compose/portainer/) - Docker container orchestration

* **Development**
  * [FastAPI](docker_compose/fastapi/) - Modern Python web framework

### Contributing

Contributions are welcome! If you'd like to add a new service or update an existing one, please fork this repository and submit a pull request.

### License

This project is licensed under the [MIT License](LICENSE).

I hope you find this repository useful for your own self-hosted services needs!
