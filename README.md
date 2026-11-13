# Minecraft Compartilhado

Um servidor de Minecraft (Java, Paper) para jogar com os amigos **sem pagar host e sem depender de uma pessoa só**.

O mundo fica guardado num repositório privado do GitHub. Qualquer pessoa do grupo pode abrir o servidor no próprio PC: o programa baixa o mundo mais recente, hosteia, e ao fechar envia o mundo de volta. Na próxima vez, outra pessoa pode hostear de onde vocês pararam.

- Só uma pessoa hosteia por vez; uma trava no repositório impede dois hosts com mundos diferentes.
- Backup automático a cada 20 minutos enquanto o servidor está aberto.
- Se o PC do host cair, outra pessoa assume a partir do último backup.
- Interface com um botão para hostear e outro para parar e salvar. Java e Paper são baixados sozinhos.

Funciona em **Windows**. Quem só vai jogar precisa apenas do Minecraft Java original.

## Este repositório é um modelo

Aqui só está o programa, sem mundo nenhum. Você não joga a partir dele: você **cria uma cópia privada para o seu grupo**, e é nela que o mundo de vocês fica.

Não dá para hostear clonando este repositório diretamente, porque ninguém além do dono consegue enviar nada para ele.

## Criar o servidor do seu grupo (uma pessoa faz, uma vez)

1. Entre na sua conta do GitHub e clique em **Use this template → Create a new repository**, no topo desta página.
2. Escolha um nome e marque **Private**. O repositório vai guardar o mundo, os nicks dos jogadores e o endereço de quem hosteia, então não deixe público.
3. No repositório novo, vá em **Settings → Collaborators** e adicione os amigos que vão poder hostear.
4. Siga os passos de "Para hostear" abaixo. Na primeira vez o mundo é gerado; feche com **Parar e salvar** para ele subir ao GitHub.

## Para hostear

Cada pessoa que for hostear precisa de uma conta no GitHub com acesso ao repositório do grupo e do [Git](https://git-scm.com/download/win) instalado.

1. Clone o repositório **do seu grupo** (não baixe o ZIP) numa pasta fora do OneDrive/Google Drive, por exemplo `C:\minecraft-do-grupo`:
   ```
   git clone https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git C:\minecraft-do-grupo
   ```
2. Dê dois cliques em `Minecraft Compartilhado.bat`. A janela mostra quem está hosteando.
3. Clique em **Hostear servidor**. Na primeira vez ele baixa o Java e o Paper e pergunta se você aceita a [EULA do Minecraft](https://aka.ms/MinecraftEULA).
4. Passe para os amigos o endereço que aparece (botão **Copiar endereço**). Você mesmo entra por `localhost`.
5. Para fechar: clique em **Parar e salvar** e espere a mensagem de mundo salvo.

Na primeira vez o Windows pergunta se o Java pode usar a rede: permita, senão ninguém consegue entrar.

Comandos do servidor (`whitelist add Fulano`, `op Fulano`...) vão na caixa de texto embaixo da janela, sem a barra.

## Como os amigos se conectam

O servidor roda no PC de quem está hosteando, então os outros precisam alcançar esse PC. O programa não resolve isso sozinho; escolham um jeito:

- **[Radmin VPN](https://www.radmin-vpn.com/)** (o mais simples): todos instalam e entram na mesma rede. O programa detecta o IP do Radmin do host e mostra o endereço pronto para copiar.
- **Outra VPN** (Tailscale, ZeroTier, Hamachi) ou **porta aberta no roteador** (25565): também funcionam, mas o programa não mostra o endereço; o host informa o próprio IP.

Como o host muda, o endereço muda junto. O `status.bat` e a interface sempre mostram quem está hosteando.

## Para jogar sem hostear

Quem tem o repositório clonado abre a interface (ou o `status.bat`) para ver quem está hosteando e o endereço. Quem não tem só precisa receber o endereço do host.

## Sem a interface (console)

| Arquivo | O que faz |
|---|---|
| `iniciar.bat` | Baixa o mundo, reserva o servidor, inicia, e ao fechar salva e envia. Para fechar digite `stop`; **não feche no X**. |
| `status.bat` | Mostra quem está hosteando, o endereço e há quanto tempo o host deu sinal. |
| `salvar.bat` | Envia o que ficou pendente quando a sessão fechou errado (janela fechada no X, internet caiu no envio). |
| `forcar.bat` | Assume o servidor mesmo com outra pessoa marcada como host. Só use se ela caiu e não vai voltar: o que ela jogou depois do último backup automático é perdido. |

## Como funciona

- Ao iniciar, o programa cria o arquivo `host.lock.json` (a "trava") e dá push. Se duas pessoas tentarem ao mesmo tempo, o GitHub aceita só o primeiro push.
- Com o servidor aberto, a cada 20 minutos ele manda o Minecraft gravar o mundo, faz um commit e envia. Cada backup também atualiza o "sinal de vida" do host na trava.
- Ao fechar, ele apaga a trava, faz commit de tudo em `server/` e dá push.
- Se o PC do host desligar no meio, a trava fica no nome dele. Quando ele abrir o programa de novo, o progresso que ficou no PC dele é enviado.
- Se ele não voltar, depois de uns 45 minutos sem sinal o status avisa que ele pode ter caído, e outra pessoa pode **Assumir o servidor** e continuar do último backup.

## Configuração

- `config.json`: versão do Minecraft (`versaoMinecraft`), versão do Java (`javaVersao`), memória do servidor (`memoria`, ex. `4G`) e intervalo do backup em minutos (`backupMinutos`; `0` desliga). Para atualizar o Minecraft, mude `versaoMinecraft`, confira no site do Paper qual Java a versão exige, e dê commit e push; o próximo host baixa o Paper novo.
- `server/server.properties`, `ops.json`, `whitelist.json` e os plugins em `server/plugins/` são sincronizados junto com o mundo. Edite com o servidor fechado e deixe o programa enviar.
- Servidores novos nascem com a whitelist ligada e vazia. Na primeira vez, digite `whitelist off` ou `whitelist add SeuNick` na caixa de comandos, senão ninguém entra.
- Só entra quem tem Minecraft original, a não ser que você mude `online-mode` no `server.properties`.

## Limites

- O GitHub recusa arquivos acima de 100 MB e recomenda repositórios de até alguns GB. Cada sessão e cada backup criam um commit com os arquivos alterados do mundo, então o histórico cresce com o tempo. Para um mundo de amigos isso dura bastante; se ficar grande, dá para recriar o repositório só com o estado atual.
- Se o PC do host quebrar de vez no meio de uma sessão, perde-se o que foi jogado desde o último backup automático (até 20 minutos).
- Se alguém assumir o servidor enquanto o host original ainda está jogando (por exemplo, só a internet dele caiu), o que for jogado no PC dele depois disso não é salvo.
- O PC de quem hosteia precisa ficar ligado e com o programa aberto enquanto os outros jogam.

## Aviso

Projeto independente, sem vínculo com a Mojang ou a Microsoft. Para rodar o servidor, cada host precisa aceitar a EULA do Minecraft.

O código deste repositório está sob a licença [MIT](LICENSE).
