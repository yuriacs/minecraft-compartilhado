# Minecraft Compartilhado

Um servidor de Minecraft (Java, Paper) para jogar com os amigos **sem pagar host e sem depender de uma pessoa só**.

O mundo fica guardado num repositório privado do GitHub. Qualquer pessoa do grupo pode abrir o servidor no próprio PC: o programa baixa o mundo mais recente, hosteia, e ao fechar envia o mundo de volta. Na próxima vez, outra pessoa pode hostear de onde vocês pararam.

- Só uma pessoa hosteia por vez; uma trava no repositório impede dois hosts com mundos diferentes.
- Backup automático a cada 20 minutos enquanto o servidor está aberto.
- Se o PC do host cair, outra pessoa assume a partir do último backup.
- Tudo por uma janela: hostear, parar e salvar, ver quem está online, whitelist e admin, restaurar um save anterior.
- Instalador de um arquivo só para os amigos, e avisos no Discord quando o servidor abre e fecha.
- Java e Paper são baixados sozinhos.

Funciona em **Windows**. Quem só vai jogar precisa apenas do Minecraft Java original.

Na pasta só há dois arquivos para usar:

| Arquivo | Para quê |
|---|---|
| `Instalar Minecraft Compartilhado.bat` | Instalar num PC novo. É o arquivo que se manda para os amigos. |
| `Minecraft Compartilhado.bat` | Abrir o programa. Tudo o resto se faz pela janela dele. |

## Este repositório é um modelo

Aqui só está o programa, sem mundo nenhum. Você não joga a partir dele: você **cria uma cópia privada para o seu grupo**, e é nela que o mundo de vocês fica.

Não dá para hostear clonando este repositório diretamente, porque ninguém além do dono consegue enviar nada para ele.

## Criar o servidor do seu grupo (uma pessoa faz, uma vez)

1. Entre na sua conta do GitHub e clique em **Use this template → Create a new repository**, no topo desta página.
2. Escolha um nome e marque **Private**. O repositório vai guardar o mundo, os nicks dos jogadores e o endereço de quem hosteia, então não deixe público.
3. No repositório novo, vá em **Settings → Collaborators** e adicione os amigos que vão poder hostear.
4. No site do GitHub, abra o arquivo `Instalar Minecraft Compartilhado.bat` do seu repositório, clique no lápis (**Edit**) e preencha a linha `set "REPO_URL="` com o link do seu repositório, por exemplo `set "REPO_URL=https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git"`. Clique em **Commit changes** e depois baixe o arquivo (**Download raw file**): é ele que você manda para os amigos.
5. Rode o instalador no seu próprio PC, abra o programa e clique em **Hostear servidor**. Na primeira vez o mundo é gerado; feche com **Parar e salvar** para ele subir ao GitHub.

Servidores novos nascem com a whitelist ligada e vazia. Na primeira vez, com o servidor aberto, desmarque **Só entra quem está na whitelist** ou ponha os nicks do grupo nela, senão ninguém entra.

## Instalar (uma vez por pessoa)

Cada pessoa que for hostear precisa de uma conta no GitHub convidada como colaboradora do repositório do grupo, com o convite já aceito.

Dê dois cliques no `Instalar Minecraft Compartilhado.bat` que o dono do grupo mandou. Ele instala o Git se faltar, baixa o servidor para `C:\MinecraftCompartilhado`, pergunta seu nick e cria o atalho **Minecraft Compartilhado** na área de trabalho. Se o instalador vier sem o link do grupo preenchido, ele pede o link na hora. Se o Windows mostrar um aviso de segurança por ser um arquivo recebido de fora, escolha executar mesmo assim.

## Hostear

1. Abra o atalho **Minecraft Compartilhado**. A janela mostra se alguém já está hosteando e o endereço para entrar.
2. Clique em **Hostear servidor**. Na primeira vez ele baixa o Java e o Paper e pergunta se você aceita a [EULA do Minecraft](https://aka.ms/MinecraftEULA).
3. Passe para os amigos o endereço que aparece (botão **Copiar endereço**). Você mesmo entra por `localhost`.
4. Para fechar: clique em **Parar e salvar** e espere a mensagem de mundo salvo. Fechar a janela no X também pergunta se quer parar e salvar.

Na primeira vez o Windows pergunta se o Java pode usar a rede: permita, senão ninguém consegue entrar.

O PC de quem hosteia precisa ficar ligado, com a janela aberta, enquanto os outros jogam.

## Como os amigos se conectam

O servidor roda no PC de quem está hosteando, então os outros precisam alcançar esse PC. O programa não resolve isso sozinho; escolham um jeito:

- **[Radmin VPN](https://www.radmin-vpn.com/)** (o mais simples): todos instalam e entram na mesma rede. O programa detecta o IP do Radmin do host e mostra o endereço pronto para copiar.
- **Outra VPN** (Tailscale, ZeroTier, Hamachi) ou **porta aberta no roteador** (25565): também funcionam, mas o programa não mostra o endereço; o host informa o próprio IP.

Como o host muda, o endereço muda junto. A janela do programa e os avisos do Discord sempre mostram quem está hosteando.

## Jogadores, whitelist e admin

Com o servidor aberto, a janela mostra à direita quem está online. Clique num jogador (ou digite o nick) e use os botões:

- **Pôr na whitelist / Tirar da whitelist**: libera ou bloqueia a entrada daquele nick.
- **Dar admin (op) / Tirar admin**.
- **Expulsar do servidor**.
- **Só entra quem está na whitelist**: liga ou desliga a whitelist inteira.

Qualquer outro comando do servidor vai na caixa de texto embaixo, sem a barra.

## Opções

O botão **Opções** só funciona com o servidor fechado, porque mexe no repositório do grupo todo.

- **Restaurar um save anterior**: mostra a lista de saves e backups e volta o mundo para o escolhido. O mundo de antes não é apagado; ele continua na lista.
- **Compactar o histórico de saves**: mantém só os N saves mais recentes e apaga os mais antigos de vez, para o repositório não crescer sem limite. Os outros PCs do grupo se realinham sozinhos na próxima vez que abrirem o programa.
- **Avisos no Discord**: o programa avisa num canal quando o servidor abre (com o endereço), fecha, ou muda de host. No Discord, no canal desejado: **Editar canal → Integrações → Webhooks → Novo webhook → Copiar URL do webhook**; cole o link na janela que abre. Para desligar, deixe o campo em branco. Quem tem o link do webhook consegue postar no canal, então ele só deve ficar em repositório privado.

## Como funciona

- Ao hostear, o programa cria o arquivo `host.lock.json` (a "trava") e dá push. Se duas pessoas tentarem ao mesmo tempo, o GitHub aceita só o primeiro push.
- Com o servidor aberto, a cada 20 minutos ele manda o Minecraft gravar o mundo, faz um commit e envia. Cada backup também atualiza o "sinal de vida" do host na trava.
- Ao fechar, ele apaga a trava, faz commit de tudo em `server/` e dá push.
- Se o PC do host desligar no meio, a trava fica no nome dele. Quando ele abrir o programa de novo, pode enviar o que ficou no PC ou continuar hosteando.
- Se ele não voltar, depois de uns 45 minutos sem sinal a janela avisa que ele pode ter caído, e outra pessoa pode **Assumir o servidor** e continuar do último backup.

## Configuração

- `scripts/config.json`: versão do Minecraft (`versaoMinecraft`), versão do Java (`javaVersao`), memória do servidor (`memoria`, ex. `4G`), intervalo do backup em minutos (`backupMinutos`; `0` desliga) e o link dos avisos do Discord. Para atualizar o Minecraft, mude `versaoMinecraft` pelo site do GitHub (lápis **Edit**), confira no site do Paper qual Java a versão exige, e salve com **Commit changes**; o próximo host baixa o Paper novo.
- `server/server.properties`, `ops.json`, `whitelist.json` e os plugins em `server/plugins/` são sincronizados junto com o mundo.
- Só entra quem tem Minecraft original, a não ser que você mude `online-mode` no `server.properties`.

## Limites

- O GitHub recusa arquivos acima de 100 MB e recomenda repositórios de até alguns GB. Cada sessão e cada backup criam um commit, então o histórico cresce; use **Compactar o histórico de saves** de tempos em tempos. No GitHub, o espaço dos saves apagados só é liberado depois de um tempo.
- Se o PC do host quebrar de vez no meio de uma sessão, perde-se o que foi jogado desde o último backup automático (até 20 minutos).
- Se alguém assumir o servidor enquanto o host original ainda está jogando (por exemplo, só a internet dele caiu), o que for jogado no PC dele depois disso não é salvo.

## Aviso

Projeto independente, sem vínculo com a Mojang ou a Microsoft. Para rodar o servidor, cada host precisa aceitar a EULA do Minecraft.

O código deste repositório está sob a licença [MIT](LICENSE).
