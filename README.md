# Minecraft Compartilhado

Um servidor de Minecraft (Java, Paper) para jogar com os amigos **sem pagar host e sem depender de uma pessoa só**.

O mundo fica guardado num repositório privado do GitHub. Qualquer pessoa do grupo pode abrir o servidor no próprio PC: o programa baixa o mundo mais recente, hosteia, e ao fechar envia o mundo de volta. Na próxima vez, outra pessoa pode hostear de onde vocês pararam.

- Só uma pessoa hosteia por vez; uma trava no repositório impede dois hosts com mundos diferentes.
- Backup automático a cada 20 minutos enquanto o servidor está aberto.
- Se o PC do host cair, outra pessoa assume a partir do último backup.
- Tudo por uma janela: hostear, parar e salvar, ver quem está online, whitelist e admin, restaurar um save anterior.
- Plugins (Paper) ou mods (Fabric), com troca de versão do Minecraft pela própria janela.
- Instalador próprio (com ícone e desinstalador, sem pedir permissão de administrador) e avisos no Discord quando o servidor abre e fecha.
- Java e Paper são baixados sozinhos.

Funciona em **Windows**. Quem só vai jogar precisa apenas do Minecraft Java original.

## Baixar

**[Baixe o instalador na página de Releases](https://github.com/yuriacs/minecraft-compartilhado/releases/latest)** (arquivo `MinecraftCompartilhado-Setup.exe`).

O instalador é gerado automaticamente pelo GitHub a partir do código deste repositório ([veja como](.github/workflows/instalador.yml)), e a página de cada versão traz o SHA-256 do arquivo. Ele ainda não tem assinatura digital, então o Windows pode mostrar "O Windows protegeu o computador": clique em **Mais informações → Executar assim mesmo**.

Antes de instalar, o seu grupo precisa ter um servidor: veja a seção seguinte se você é quem vai criar.

## Este repositório é um modelo

Aqui só está o programa, sem mundo nenhum. Você não joga a partir dele: você **cria uma cópia privada para o seu grupo**, e é nela que o mundo de vocês fica.

Não dá para hostear clonando este repositório diretamente, porque ninguém além do dono consegue enviar nada para ele.

## Criar o servidor do seu grupo (uma pessoa faz, uma vez)

1. Entre na sua conta do GitHub e clique em **Use this template → Create a new repository**, no topo desta página.
2. Escolha um nome e marque **Private**. O repositório vai guardar o mundo, os nicks dos jogadores e o endereço de quem hosteia, então não deixe público.
3. No repositório novo, vá em **Settings → Collaborators** e adicione os amigos que vão poder hostear.
4. Instale o programa (seção "Instalar" abaixo) e, na primeira tela, cole o link do repositório que você acabou de criar.
5. Clique em **Hostear servidor**. Na primeira vez o mundo é gerado; feche com **Parar e salvar** para ele subir ao GitHub.
6. Passe para os amigos o link do repositório do grupo e o link do instalador.

Servidores novos nascem com a whitelist ligada e vazia. Na primeira vez, com o servidor aberto, desmarque **Só entra quem está na whitelist** ou ponha os nicks do grupo nela, senão ninguém entra.

## Instalar (uma vez por pessoa)

Cada pessoa que for hostear precisa de uma conta no GitHub convidada como colaboradora do repositório do grupo, com o convite já aceito.

1. Baixe o `MinecraftCompartilhado-Setup.exe` na [página de Releases](https://github.com/yuriacs/minecraft-compartilhado/releases/latest) e execute. Ele não pede permissão de administrador e cria o atalho **Minecraft Compartilhado** no menu Iniciar e na área de trabalho.
2. Na primeira vez que abrir, cole o **link do grupo** (o endereço do repositório privado do grupo, que o dono passa) e escolha seu nick. O programa instala o Git se faltar e baixa o servidor para `C:\MinecraftCompartilhado`. Se abrir uma janela de login do GitHub, entre com a conta que foi convidada.

Para remover, use **Configurações → Aplicativos** do Windows. A pasta do mundo não é apagada junto.

## Hostear

1. Abra o atalho **Minecraft Compartilhado**. A janela mostra se alguém já está hosteando e o endereço para entrar.
2. Clique em **Hostear servidor**. Na primeira vez ele baixa o Java e o Paper e pergunta se você aceita a [EULA do Minecraft](https://aka.ms/MinecraftEULA).
3. Passe para os amigos o endereço que aparece (botão **Copiar endereço**). Você mesmo entra por `localhost`.
4. Para fechar: clique em **Parar e salvar** e espere a mensagem de mundo salvo. Fechar a janela no X também pergunta se quer parar e salvar.

Na primeira vez o Windows pergunta se o Java pode usar a rede: permita, senão ninguém consegue entrar.

O PC de quem hosteia precisa ficar ligado, com a janela aberta, enquanto os outros jogam.

## Como os amigos se conectam

O servidor roda no PC de quem está hosteando, então os outros precisam alcançar esse PC. O programa não resolve isso sozinho; escolham um jeito:

- **Túnel do playit.gg**: quem joga não instala nada, só digita um endereço fixo. O programa sobe o túnel sozinho quando alguém hosteia. Veja como ligar em "Opções → Conexão por túnel", mais abaixo.
- **[Radmin VPN](https://www.radmin-vpn.com/)**: todos instalam e entram na mesma rede. O programa detecta o IP do Radmin do host e mostra o endereço pronto para copiar.
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

Quase tudo em **Opções** só funciona com o servidor fechado, porque mexe no repositório do grupo todo.

- **Plugins do servidor** (ou **Mods do servidor**, se o servidor for Fabric): adiciona e remove os arquivos `.jar` e envia a mudança para o grupo. Não coloque arquivos direto na pasta: use esta opção, que é ela que grava no GitHub.
- **Tipo de servidor e versão do Minecraft**: escolhe entre **Paper** (aceita plugins; quem joga usa o Minecraft normal) e **Fabric** (aceita mods; todos precisam do Fabric e dos mesmos mods), e a versão do jogo. O programa acerta sozinho a versão do Java. Trocar entre Paper e Fabric começa um mundo novo, porque um não abre o mundo do outro; o mundo anterior continua guardado nos saves.
- **Mods para jogar neste PC** (só aparece com servidor Fabric): explica como instalar o Fabric e copia os mods do grupo para a pasta de mods do seu Minecraft, sem apagar os que você colocou por conta própria. Com mods, quem só joga também precisa instalar este programa.
- **Memória do servidor neste PC**: quanto de memória o servidor usa quando você hosteia. É um ajuste só do seu PC; os outros continuam com o deles. Esta opção funciona mesmo com o servidor de outra pessoa aberto.
- **Atualizar o programa** (aparece quando há versão nova): baixa a versão mais recente do programa e grava para o grupo todo.
- **Restaurar um save anterior**: mostra a lista de saves e backups e volta o mundo para o escolhido. O mundo de antes não é apagado; ele continua na lista.
- **Compactar o histórico de saves**: mantém só os N saves mais recentes e apaga os mais antigos de vez, para o repositório não crescer sem limite. Os outros PCs do grupo se realinham sozinhos na próxima vez que abrirem o programa.
- **Avisos no Discord**: o programa avisa num canal quando o servidor abre (com o endereço), fecha, ou muda de host. No Discord, no canal desejado: **Editar canal → Integrações → Webhooks → Novo webhook → Copiar URL do webhook**; cole o link na janela que abre. Para desligar, deixe o campo em branco. Quem tem o link do webhook consegue postar no canal, então ele só deve ficar em repositório privado.

- **Conexão por túnel (sem Radmin)**: usa o [playit.gg](https://playit.gg) (plano gratuito) para dar ao servidor um endereço público. Quem hosteia sobe o túnel automaticamente; quem joga não instala nada, só digita o endereço. Como configurar:
  1. Crie uma conta no playit.gg e adicione um agente do tipo **Docker**. Copie o valor que aparece depois de `SECRET_KEY=` (não precisa rodar o comando).
  2. Em **Opções → Conexão por túnel**, cole a chave e salve, deixando o endereço em branco.
  3. Clique em **Hostear servidor** uma vez. O programa baixa o agente oficial do playit, e o site passa a reconhecê-lo.
  4. No site do playit, crie um túnel **Minecraft Java** para a porta local `25565` e copie o endereço que ele mostra (algo como `nome.gl.joinmc.link`).
  5. Feche o servidor, volte em **Opções → Conexão por túnel** e preencha o endereço (a chave pode ficar em branco, ela é mantida).

  Com o túnel, o servidor fica alcançável pela internet: mantenha ligada a opção **Só entra quem está na whitelist**. A conexão passa pelos servidores do playit, então o ping tende a ser um pouco maior que no Radmin. A chave fica no `config.json`; mantenha o repositório privado.

## Como funciona

- Ao hostear, o programa cria o arquivo `host.lock.json` (a "trava") e dá push. Se duas pessoas tentarem ao mesmo tempo, o GitHub aceita só o primeiro push.
- Com o servidor aberto, a cada 20 minutos ele manda o Minecraft gravar o mundo, faz um commit e envia. Cada backup também atualiza o "sinal de vida" do host na trava.
- Ao fechar, ele apaga a trava, faz commit de tudo em `server/` e dá push.
- Se o PC do host desligar no meio, a trava fica no nome dele. Quando ele abrir o programa de novo, pode enviar o que ficou no PC ou continuar hosteando.
- Se ele não voltar, depois de uns 45 minutos sem sinal a janela avisa que ele pode ter caído, e outra pessoa pode **Assumir o servidor** e continuar do último backup.

## Configuração

- `scripts/config.json`: guarda o que vale para o grupo (tipo e versão do servidor, memória padrão, intervalo do backup em `backupMinutos`, Discord e túnel). Quase tudo se muda por **Opções**; só o intervalo do backup e a memória padrão do grupo (`memoria`) são editados à mão, pelo site do GitHub (lápis **Edit**).
- `server/server.properties`, `ops.json`, `whitelist.json` e os plugins em `server/plugins/` são sincronizados junto com o mundo.
- Só entra quem tem Minecraft original, a não ser que você mude `online-mode` no `server.properties`.

## Limites

- O GitHub recusa arquivos acima de 100 MB e recomenda repositórios de até alguns GB. Cada sessão e cada backup criam um commit, então o histórico cresce; use **Compactar o histórico de saves** de tempos em tempos. No GitHub, o espaço dos saves apagados só é liberado depois de um tempo.
- Se o PC do host quebrar de vez no meio de uma sessão, perde-se o que foi jogado desde o último backup automático (até 20 minutos).
- Se alguém assumir o servidor enquanto o host original ainda está jogando (por exemplo, só a internet dele caiu), o que for jogado no PC dele depois disso não é salvo.

## Aviso

Projeto independente, sem vínculo com a Mojang ou a Microsoft. Para rodar o servidor, cada host precisa aceitar a EULA do Minecraft.

O código deste repositório está sob a licença [MIT](LICENSE).
