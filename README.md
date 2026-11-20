# Industry Evolution — versão web

Jogo independente em HTML, CSS e JavaScript, sem bibliotecas/CDNs. O GitHub Pages pode servir esta pasta diretamente. O desenho usa Canvas com projeção isométrica e formas low-poly, com coordenadas e objetos em espaço 3D; é uma versão leve para navegador, não requer plug-in.

## Publicar no GitHub Pages

Envie os arquivos desta pasta para a raiz do repositório. No GitHub, abra **Settings → Pages**, escolha a branch publicada e a pasta `/ (root)`. A página usa `index.html` como entrada. Também pode ser publicada como `/docs` se mover todos os arquivos juntos para essa pasta. O primeiro carregamento precisa acessar a página publicada; depois o service worker guarda o app shell e permite abrir a página offline nesse mesmo navegador e endereço.

## Como jogar

- No computador: **Continuar** para começar e use **WASD** ou as setas. **E** ou **Espaço** interage com a plataforma física de melhoria e o portal de setores.
- No celular: arraste no lado esquerdo da tela para mover; o joystick aparece sob o toque. Os botões de ação aparecem quando você chega às estações.
- Colha perto do campo, leve o recurso ao processador, recolha o produto pronto, entregue no caixa e aguarde clientes. A venda deposita moedas junto ao caixa; elas são recolhidas automaticamente quando você se aproxima.
- Caminhe até a plataforma dourada para comprar a próxima melhoria. Use o portal azul para abrir um setor com moedas e viajar pelos setores já abertos.
- O jogo tem 20 setores, produtos/valores por setor, progresso econômico crescente, automação gradual, funcionários, menu, configurações e salvamento local versionado. A opção **Novo jogo** e a opção de apagar o save pedem confirmação.

O progresso usa `localStorage` no navegador e fica separado para cada endereço/site. Não há conta, telemetria, integração de doações ou transação de pagamento. Os itens de privacidade/termos são informativos para este protótipo.