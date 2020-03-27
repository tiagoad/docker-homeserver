# Docker Homeserver Infrastructrue

This is my setup to deploy my entire home infrastructure in a single command (after installing docker and turning swarm on)

It depends on docker swarm, and separates containers into stacks of related software, deployed using the `deploy.sh` script.

Traefik v2 serves as a reverse proxy, relying on Authelia in file mode to authenticate users.

The following services are configured:

! - requires manual setup on the web interface, refer to the manuals for instructions.

- bots
  - [mlbot](https://github.com/tiagoad/mlbot) (twitter lisbon metro alerts)
- docker
  - [portainer](https://hub.docker.com/r/portainer/portainer/) (docker dashboard)
  - [agent](https://hub.docker.com/r/portainer/agent/) (docker swarm agent for access to each individual server)
- documentation
  - ! [heimdall](https://hub.docker.com/r/linuxserver/heimdall/) (web interface dashboard)
- distrosharing
  - [transmission-oc](https://hub.docker.com/r/tiagoad/transmission) (torrent client number 1)
  - transmission-archive1 (torrent client number 2)
  - ! [sabnzbd](https://hub.docker.com/r/linuxserver/sabnzbd) (usenet client)
  - ! [hydra2](https://hub.docker.com/r/linuxserver/hydra2) (usenet indexer aggregator)
  - ! [sonarr](https://hub.docker.com/r/linuxserver/sonarr) (usenet tv indexer)
  - ! [radarr](https://hub.docker.com/r/linuxserver/radarr) (usenet cinema indexer)
  - ! [bazarr](https://hub.docker.com/r/linuxserver/bazarr) (usenet subtitle downloader)
- http
  - [traefik](https://hub.docker.com/r/_/traefik) (reverse proxy)
  - [authelia](https://hub.docker.com/r/authelia/authelia) (single sign-on)
- media
  - ! [airsonic](https://hub.docker.com/r/linuxserver/airsonic) (music streaming)
- sites
  - [tdias](https://tdias.tech) (personal site nginx placeholder)
- system
  - system-prune (prunes unused docker resources every hour)

## Assumptions

I assume:

1. You have a host running docker, with rsync and docker-compose installed
2. You have a domain with a wildcard A record pointing to your home server, with TCP ports 80, 443, and 13000-13500 open to the outside.

Also, my setup right now:

1. Only has a single machine, I plan to add a couple VPS for DNS and e-mail, as well as moving authentication over there.


## Problems with this setup

**All the containers with reverse proxy configuration can talk to each other.**

All of the containers with reverse proxy configuration them are in the same "http" network to allow communication with Traefik. This allows all the applications to access eachother's control panels, which would be a big problem if all my apps were open to the outside. 

Right now only Traefik, Authelia and an nginx server can be accessed without Authelia authentication, and Authelia is on a different network with no access from containers other than Traefik. This kind of setup could be replicated to all other containers, but I'll perhaps want to use some sort of configuration generation to handle that (yeah, I know).

**Docker can access a lot of data**

On my setup, Docker can access all the data on my NAS, except for what's decrypted remotely over NFS on my laptop. It would be good to limit what the engine can access, and I'll work on that eventually.

**You must change the swarm configuration names every time you change the contents, as these are write-only**

I'm using `var_name_v5` type names.


## Deployment

1. Create secrets.env and production.env, and replace the remaining example files (like in the http stack).
2. Set your desired deploy.sh environment variables and run `./deploy.sh all up`
3. Setup the apps requiring manual setup

`deploy.sh` will:

1. If ssh mode, open an SSH connection to the remote host
2. Run global `_setup.sh` on remote host
4. If up mode: For each stack, run `docker stack deploy --prune --compose-file "docker-compose.yml" "$stack"`
3. If down mode: For each stack, run local `_setup.sh`
5. If down mode: For each stack, run `docker stack rm "$stack"`

`deploy.sh` accepts the following environment variables:

|                        | description                                                      | default        |
|------------------------|------------------------------------------------------------------|----------------|
| DDEPLOY_MODE           | **local**: run commands locally \| **ssh**: run commands on a remote server | local          |
| DDEPLOY_SSH_USER       | ssh username                                                     | root           |
| DDEPLOY_SSH_HOST       | ssh password                                                     | 127.0.0.1      |
| DDEPLOY_SSH_PORT       | ssh port                                                         | 22             |
| DDEPLOY_REMOTE_TMP_DIR | remote temporary directory for compose files                     | /opt/compose   |
| DDEPLOY_SECRETS_FILE   | secrets                                                          | secrets.env    |
| DDEPLOY_ENV_FILE       | environment vars                                                 | production.env |
example:

    DDEPLOY_MODE=ssh DDEPLOY_SSH_HOST=192.168.1.40 ./deploy.sh all up

or...

	# (you can add this to your shell rc file, like .bashrc or .zshrc)
	export DDEPLOY_MODE=ssh
	export DDEPLOY_SSH_HOST=192.168.1.40 

	./deploy.sh all up
 
   
## Troubleshooting

**Useful commands**
  
    # docker service ps <stack_service> --no-trunc
    # docker service logs <stack_service> -f
    # docker service scale <stack_service>=<replicas>

**Nothing on ports 80 and 443 (denied connection)**

Traefik is not running. Check the running status (`docker service ps http_traefik --no-trunc`) and service logs (`docker service logs http_traefik`).

**Domain replies with wrong certificate or 404**

Check the container logs to check if it's running. Check the traefik control panel to check if the service has been registered.

If it has been registered, Traefik is probably registering the certificate with Let's Encrypt. If it hasn't, there's probably some problem with your container.

**Gateway times out**

You probably didn't add the container to the http network.
