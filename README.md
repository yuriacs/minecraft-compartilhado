# Minecraft Compartilhado

**English** · [Português](README.pt-BR.md)

A Minecraft server (Java, Paper) to play with your friends **without paying for hosting and without depending on a single person**.

The world is kept in a private GitHub repository. Anyone in the group can open the server on their own PC: the program downloads the latest world, hosts it, and when it closes it uploads the world back. Next time, someone else can host from where you left off.

- Only one person hosts at a time; a lock in the repository prevents two hosts with different worlds.
- Automatic backup every 20 minutes while the server is open.
- If the host's PC goes down, someone else takes over from the latest backup.
- Everything from one window: host, stop and save, see who is online, whitelist and admin, restore a previous save.
- Plugins (Paper) or mods (Fabric, NeoForge, Forge), modpack import and Minecraft version changes from the window itself.
- Its own installer (with an icon and uninstaller, no administrator permission needed) and Discord notifications when the server opens and closes.
- Java and the server are downloaded automatically.
- In English or Portuguese, following the Windows language (it can be changed in the program).

Works on **Windows**. People who only play just need the official Minecraft Java Edition.

## Download

**[Download the installer from the Releases page](https://github.com/yuriacs/minecraft-compartilhado/releases/latest)** (file `MinecraftCompartilhado-Setup.exe`).

The installer is built automatically by GitHub from the code in this repository ([see how](.github/workflows/instalador.yml)), and each release page shows the file's SHA-256. It doesn't have a digital signature yet, so Windows may show "Windows protected your PC": click **More info → Run anyway**.

Before installing, your group needs a server: see the next section if you are the one creating it.

## This repository is a template

It only has the program, no world. You don't play from it: you **create a private copy for your group**, and that is where your world lives.

You can't host by cloning this repository directly, because nobody but its owner can upload anything to it.

## Create your group's server (one person, once)

1. Sign in to GitHub and click **Use this template → Create a new repository**, at the top of this page.
2. Pick a name and select **Private**. The repository will store the world, the players' nicknames and the address of whoever is hosting, so don't make it public.
3. In the new repository, go to **Settings → Collaborators** and add the friends who will be able to host.
4. Install the program (see "Install" below) and, on the first screen, paste the link of the repository you just created.
5. Click **Host server**. The first time, the world is generated; close it with **Stop and save** so it gets uploaded to GitHub.
6. Send your friends the link to the group's repository and the link to the installer.

New servers start with the whitelist on and empty. The first time, with the server open, uncheck **Only whitelisted players can join** or add your group's nicknames to it, otherwise nobody can join.

## Install (once per person)

Everyone who will host needs a GitHub account invited as a collaborator to the group's repository, with the invitation already accepted.

1. Download `MinecraftCompartilhado-Setup.exe` from the [Releases page](https://github.com/yuriacs/minecraft-compartilhado/releases/latest) and run it. It doesn't ask for administrator permission and creates a **Minecraft Compartilhado** shortcut in the Start menu and on the desktop.
2. The first time you open it, paste the **group link** (the address of the group's private repository, which the owner gives you) and choose your nickname. The program installs Git if it's missing and downloads the server to `C:\MinecraftCompartilhado`. If a GitHub sign-in window opens, sign in with the account that was invited.

To remove it, use Windows **Settings → Apps**. The world folder is not deleted along with it.

## Hosting

1. Open the **Minecraft Compartilhado** shortcut. The window shows whether someone is already hosting and the address to join.
2. Click **Host server**. The first time, it downloads Java and the server and asks whether you accept the [Minecraft EULA](https://aka.ms/MinecraftEULA).
3. Give your friends the address it shows (**Copy address** button). You join through `localhost`.
4. To close: click **Stop and save** and wait for the "world saved" message. Closing the window with the X also asks whether you want to stop and save.

The first time, Windows asks whether Java may use the network: allow it, otherwise nobody can join.

The host's PC needs to stay on, with the window open, while the others play.

## How friends connect

The server runs on the host's PC, so the others need to reach that PC. Choose a way:

- **Direct connection** (Options): the program asks the host's router to open the port and friends connect straight to the host's public IP, with the lowest ping. It only works if the router allows it (UPnP) and the ISP doesn't share the IP (CGNAT); otherwise it falls back to the options below.
- **playit.gg tunnel** (Options): players don't install anything, they just type a fixed address. The program starts the tunnel by itself when someone hosts.
- **[Radmin VPN](https://www.radmin-vpn.com/)**: everyone installs it and joins the same network. The program detects the host's Radmin IP and shows the address ready to copy.
- **Another VPN** (Tailscale, ZeroTier, Hamachi) or a **manually opened router port** (25565): these also work, but the program doesn't show the address; the host shares their own IP.

Since the host changes, the address changes with it. The program window and the Discord notifications always show who is hosting.

## Players, whitelist and admin

With the server open, the window shows on the right who is online. Click a player (or type the nickname) and use the buttons:

- **Add to whitelist / Unwhitelist**: allows or blocks that nickname.
- **Make admin (op) / Remove admin**.
- **Kick from server**.
- **Only whitelisted players can join**: turns the whole whitelist on or off.

Any other server command goes in the text box at the bottom, without the slash.

## Options

Almost everything in **Options** only works with the server closed, because it changes the whole group's repository.

- **Server plugins** (or **Server mods**, on a modded server): adds and removes `.jar` files and uploads the change for the group. Don't put files straight into the folder: use this option, which is what saves to GitHub.
- **Server type and Minecraft version**: chooses between **Paper** (accepts plugins; players use regular Minecraft) and a modded server (**Fabric**, or **NeoForge** and **Forge**, which are still experimental), and the game version. The program picks the right Java and mod loader versions. Switching between Paper and a modded server starts a new world, because one can't open the other's world; the previous world is still kept in the saves.
- **Import modpack**: installs a whole modpack on the server, from a **Server Pack** (the server `.zip` that CurseForge modpacks offer in the Files tab) or a Modrinth **.mrpack**. The program works out the loader and versions, you check them, and it replaces the server's mods and configs. Players install the same modpack through the CurseForge or Modrinth app. The CurseForge pack for the game (the one that only has the list of mods) won't work: it has to be the Server Pack.
- **Mods to play on this PC** (only shown on a modded server): explains how to install the mod loader and copies the group's mods into your Minecraft mods folder, without deleting the ones you added yourself. With mods, people who only play also need this program.
- **This PC's settings**: how much memory the server uses when you host, the program language, and whether it should **close by itself when empty** (it saves the world and frees the turn after some time with nobody online). They apply only to your PC and can be changed even while someone else's server is open. While you host, the program already keeps the PC from going to sleep due to inactivity.
- **Update the program** (shown when there is a new version): downloads the latest version of the program and saves it for the whole group.
- **Restore a previous save**: shows the list of saves and backups and takes the world back to the chosen one. The world from before is not deleted; it stays in the list.
- **Compact the save history**: keeps only the N most recent saves and deletes the older ones for good, so the repository doesn't grow without limit. The group's other PCs realign by themselves the next time they open the program.
- **Discord notifications**: the program posts in a channel when the server opens (with the address), closes, or changes host. In Discord, on the channel you want: **Edit Channel → Integrations → Webhooks → New Webhook → Copy Webhook URL**; paste the link in the window that opens. To turn it off, leave the field empty. Anyone with the webhook link can post in the channel, so it should only be kept in a private repository.
- **Direct connection (router port)**: the host asks their own router to open the server port (UPnP), and friends connect directly to the host's public IP, without Radmin and with the lowest ping. If the tunnel is set up, it stays on as a backup address. The shared address becomes the public IP of the host's home.
- **Tunnel connection (no Radmin)**: uses [playit.gg](https://playit.gg) (free plan) to give the server a public address. The host starts the tunnel automatically; players don't install anything, they just type the address. How to set it up:
  1. Create a playit.gg account and add an agent of type **Docker**. Copy the value shown after `SECRET_KEY=` (you don't need to run the command).
  2. In **Options → Tunnel connection**, paste the key and save, leaving the address empty.
  3. Click **Host server** once. The program downloads the official playit agent, and the site recognizes it.
  4. On the playit site, create a **Minecraft Java** tunnel for local port `25565` and copy the address it shows (something like `name.gl.joinmc.link`).
  5. Close the server, go back to **Options → Tunnel connection** and fill in the address (the key can stay empty; it is kept).

  With the tunnel or the direct connection, the server is reachable from the internet: keep **Only whitelisted players can join** on. The tunnel goes through playit's servers, so the ping tends to be a bit higher than with Radmin. The key is stored in `config.json`; keep the repository private.

## How it works

- When hosting, the program creates the `host.lock.json` file (the "lock") and pushes it. If two people try at the same time, GitHub accepts only the first push.
- With the server open, every 20 minutes it tells Minecraft to save the world, makes a commit and pushes it. Each backup also updates the host's "heartbeat" in the lock.
- When closing, it removes the lock, commits everything in `server/` and pushes.
- If the host's PC turns off midway, the lock stays in their name. When they open the program again, they can upload what was left on the PC or keep hosting.
- If they don't come back, after about 45 minutes without a heartbeat the window warns that they may have dropped, and someone else can **Take over the server** and continue from the latest backup.

## Configuration

- `scripts/config.json`: stores what applies to the group (server type and version, default memory, backup interval in `backupMinutos`, Discord, tunnel and direct connection). Almost everything is changed through **Options**; only the backup interval, the group's default memory (`memoria`) and the language of the Discord notifications (`idiomaGrupo`: `"en"` or `"pt"`; empty uses each host's language) are edited by hand, on the GitHub website (pencil **Edit**).
- `server/server.properties`, `ops.json`, `whitelist.json` and the plugins in `server/plugins/` are synced along with the world.
- Only people with official Minecraft can join, unless you change `online-mode` in `server.properties`.
- The program code, and the messages saved in the repository history, use Portuguese names (for example `config.json` keys and commit messages). That doesn't affect what you see in the program.

## Limits

- GitHub rejects files over 100 MB and recommends repositories of up to a few GB. Each session and each backup creates a commit, so the history grows; use **Compact the save history** from time to time. On GitHub, the space of deleted saves is only freed after a while.
- If the host's PC breaks for good in the middle of a session, whatever was played since the latest automatic backup is lost (up to 20 minutes).
- If someone takes over the server while the original host is still playing (for example, only their internet dropped), whatever is played on the original host's PC after that is not saved.

## Disclaimer

Independent project, not affiliated with Mojang or Microsoft. To run the server, each host needs to accept the Minecraft EULA.

The code in this repository is under the [MIT](LICENSE) license.
