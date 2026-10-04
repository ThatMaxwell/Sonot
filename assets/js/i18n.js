/* ==========================================================================
   SONOT — translations (English is the page itself; Portuguese lives here)
   ========================================================================== */
(function () {
  'use strict';

  /* Page text, keyed by CSS selector.
     A string replaces the element's HTML, an array maps onto every match in
     order, and { last: '...' } swaps only the element's final text node
     (for elements that also hold icons). */
  var PT = {
    // Loader
    '.loader-meta > span:first-child': 'Acordando',

    // Launch film
    '.film-label': { last: 'Sonot — Filme de lançamento' },
    '#filmSkip': 'Pular intro <kbd>Esc</kbd>',
    '.o-1': 'Toda grande ideia',
    '.o-2': 'começa com uma <em>pergunta.</em>',
    '.b-tag': 'Seu parceiro de raciocínio mais brilhante.',
    '.sc-ask .kicker': '<span>01</span> Pergunte qualquer coisa',
    '.ans-head span': '3 dias · Kyoto · $742 no total',
    '.day i': ['Dia 1', 'Dia 2', 'Dia 3'],
    '.day > div': [
      '<b>Fushimi Inari ao nascer do sol</b><span>Fuja das multidões · ¥0 · depois almoço no Mercado Nishiki</span>',
      '<b>Bambuzal de Arashiyama + passeio no rio</b><span>Bate-volta com JR Pass · jantar kaiseki de tofu</span>',
      '<b>Gion, Kiyomizu-dera e cerimônia do chá</b><span>Tudo a pé · pousada perto do rio Kamo</span>'
    ],
    '.budget-top > span:first-child': 'Orçamento',
    '.sc-think .kicker': '<span>02</span> Raciocina passo a passo',
    '.think-title': 'Pensa <em>antes</em> de falar.',
    '.steps li': ['<i></i>Lendo 24 fontes', '<i></i>Checando os fatos', '<i></i>Fazendo as contas', '<i></i>Encontrando a pegadinha', '<i></i>Explicando de um jeito que faz sentido'],
    '.sc-code .kicker': '<span>03</span> Constrói',
    '.code-title': 'Escreve código que <em>roda.</em>',
    '.tl.t5': '<u>42 passaram</u> · 0 falharam',
    '.sc-see .kicker': '<span>04</span> Enxerga',
    '.bx2 span': 'Notebook',
    '.bx3 span': 'Suculenta',
    '.bx4 span': 'Luminária',
    '.see-cap p': 'Um espaço de trabalho claro e organizado. Levante o notebook uns 8 cm e seu pescoço agradece.',
    '.see-title': 'Entende o que <em>vê.</em>',
    '.every-copy .kicker': '<span>05</span> Em todo lugar',
    '.every-copy h3': 'Em todas as <em>suas telas.</em>',
    '.mont figcaption': [
      '“Explique buracos negros como se eu tivesse dez anos.”',
      '“Por que meu código está tão lento?”',
      '“Dá um nome pro meu novo podcast.”',
      '“Resume esse relatório de 40 páginas.”',
      '“Precifica meu cardápio pra dar lucro.”',
      '“Planeja nossa viagem de carro.”',
      '“Me ajuda a dizer não — com educação.”'
    ],
    '.mont-final': 'Toda pergunta merece<br />uma resposta <em>brilhante.</em>',
    '.fin-tag': 'Pense com mais <em>brilho.</em>',
    '.fin-by': { last: 'Feito por ThatMaxwell' },
    '.fin-avail': 'Já disponível para computador e celular',

    // Nav + hero
    '.nav-links a': ['Computador', 'Celular', 'Recursos', 'Pessoas', 'Experimente'],
    '.nav .btn span': 'Baixar',
    '.hero .eyebrow': { last: 'Apresentando o Sonot 1.0' },
    '.hero-title .hl:nth-child(1) > span': 'A mente mais brilhante',
    '.hero-title .hl:nth-child(2) > span': 'que você vai <em>conhecer.</em>',
    '.hero-sub': 'O Sonot lê, raciocina, escreve, programa, enxerga e fala — no seu computador e no seu bolso.',
    '#watchFilm': '<span class="play"><svg viewBox="0 0 24 24"><path d="M8 5.5v13l11-6.5z" fill="currentColor" /></svg></span>Assistir ao filme <small>0:49</small>',
    '.hero-plat': 'Grátis · macOS · Windows · Linux · iOS · Android',
    '.manifesto-text': 'O Sonot lê, raciocina, escreve, programa, enxerga e fala. Lembra do que importa, esquece o que você pedir e nunca te deixa esperando. É o assistente que o Maxwell sempre quis — então ele mesmo criou.',

    // Desktop showcase
    '.desk-head .eyebrow': 'App para computador',
    '.desk-head .h2': 'Seu computador, <em>agora brilhante.</em>',
    '.osbar-mac .l span': ['Arquivo', 'Editar', 'Visualizar', 'Janela', 'Ajuda'],
    '.osbar-mac .r > span:last-child': 'Dom 4 out&nbsp; 9:41',
    '.osbar-linux .act': 'Atividades',
    '.osbar-linux .c': '4 out&nbsp; 09:41',
    '.aw-new': '＋ Nova conversa <kbd>⌘N</kbd>',
    '.aw-search': '⌕ Buscar',
    '.aw-sec': ['Hoje', 'Esta semana'],
    '.aw-item': ['Kyoto com pouco dinheiro', 'Corrigir bug no login', 'Redação: clima e cidades', 'Relatório T3 — pontos-chave', 'Problemas com fermentação natural', 'Brinde de aniversário da Mia', 'Aprender espanhol: dia 12'],
    '.aw-user small': 'Sonot Grátis',
    '.aw-head b': 'Kyoto com pouco dinheiro',
    '.m-user': 'Tenho 3 dias em Kyoto em novembro e $800. Faz ser inesquecível — amo comida, templos e caminhadas longas.',
    '.thinking': 'Pensou por 4s',
    '.m-card': [
      '<i>Dia 1</i><b>Fushimi Inari às 6h</b><span>Almoço no Nishiki · jantar em Pontocho</span>',
      '<i>Dia 2</i><b>Arashiyama e Sagano</b><span>Bambuzal · kaiseki de tofu · passeio de barco</span>',
      '<i>Dia 3</i><b>Momiji em Eikan-do</b><span>Caminho do Filósofo · chá em Gion</span>'
    ],
    '.m-chips span': ['Adicionar mapa de comida', 'Hostels por menos de $40', 'Plano B para dia de chuva'],
    '.aw-composer .ph': 'Pergunte qualquer coisa ao Sonot…',
    '.q-res b': 'Versão mais simpática',
    '.q-res p': '“Oi, pessoal! Rapidinho: o lançamento foi pra quinta pra gente caprichar em alguns detalhes. Valeu por toparem — vocês são demais.”',
    '.q-acts span': ['↵ Substituir', '⌘C Copiar'],
    '.desk-notes p': [
      '<b>Mora no seu computador.</b> Um app nativo que abre num piscar de olhos e não atrapalha.',
      '<b>Pergunta Rápida, em qualquer lugar.</b> Aperte <kbd>⌥ Space</kbd> sobre qualquer app para reescrever, explicar ou traduzir.'
    ],

    // Phones
    '.phones .eyebrow': 'iOS e Android',
    '.phones .h2': 'No seu bolso. <em>Sempre ligado.</em>',
    '.phones .lede': 'Pergunte em voz alta numa caminhada, tire foto de um cardápio ou receba um aviso antes do seu dia começar.',
    '.ls-date': 'domingo, 4 de outubro',
    '.lw-head span': 'agora',
    '.ls-widget p': '<b>Bom dia, Maxwell ☀️</b> Chuva a partir das 15h — leve um casaco. Sua reunião das 10h30 foi pras 11h, então dá tempo de um café.',
    '.ls-notif span': 'Sua sequência de espanhol: dia 12 🔥',
    '.pc-head b': 'E-mail do aquecedor',
    '.pm-user': 'Me ajuda a avisar o proprietário que o aquecedor quebrou de novo. Firme, mas educado?',
    '.pm-bot > p': 'Aqui vai um rascunho:',
    '.pm-draft': '<b>Assunto: Conserto do aquecedor — segundo pedido</b><p>Oi, Dana. O aquecedor do 4B parou de funcionar de novo no dia 2/10. Com o frio chegando, dá para agendar o conserto até sexta? Posso ficar em casa para receber o técnico. Obrigado!</p>',
    '.pm-acts span': ['Mais curto', 'Mais gentil', 'Enviar ↗'],
    '.pc-comp .ph': 'Mensagem',
    '.pv-label': 'Voz · Ouvindo',
    '.pv-you': '“Que nome dou pro meu filhote de golden retriever?”',
    '.pv-ans': 'Sunny, Maple ou Biscoito — e se ela for meio bagunceira, <b>Waffle</b>.',

    // Capabilities
    '.talents .eyebrow': 'Recursos',
    '.talents .h2': 'Uma mente. <em>Todos os talentos.</em>',
    '.t-reason .t-copy': '<h3>Raciocínio</h3><p>Divide problemas difíceis em etapas, confere o próprio trabalho e mostra o porquê.</p>',
    '.t-steps li': ['Entender a pergunta', 'Planejar a abordagem', 'Resolver passo a passo', 'Conferir a resposta'],
    '.t-code .t-copy': '<h3>Código</h3><p>Escreve, explica, refatora e depura em mais de 40 linguagens.</p>',
    '.t-vision .t-copy': '<h3>Visão</h3><p>Fotos, prints, gráficos, letra de mão. É só mostrar.</p>',
    '.t-voice .t-copy': '<h3>Voz</h3><p>Conversa natural que acompanha seu ritmo — interrompa quando quiser.</p>',
    '.t-memory .t-copy': '<h3>Memória</h3><p>Lembra do que você escolher. Esquece quando você pedir.</p>',
    '.chips span': ['Vegetariano', 'Usa sistema métrico', 'Aprendendo espanhol', 'Odeia e-mails longos', 'Coruja noturna'],
    '.t-private .t-copy': '<h3>Privado por padrão</h3><p>Suas conversas são suas. Apague tudo com um toque.</p>',
    '.t-write .t-copy': '<h3>Escrita</h3><p>A mesma ideia, em qualquer tom.</p>',
    '.tone-tabs span': ['Amigável', 'Formal', 'Direto'],
    '.t-fast .t-copy': '<h3>Rápido</h3><p>Começa a responder antes de você piscar.</p>',
    '.speed small': 'até a primeira palavra*',
    '.fineprint': '*Número de prévia — os valores finais chegam com o lançamento público.',

    // People
    '.people-head .eyebrow': 'Para todo mundo',
    '.people-head .h2': 'Feito para o seu <em>jeito</em> de pensar.',
    '.pc-tag': ['Estudantes', 'Devs', 'Criadores', 'Profissionais', 'Pequenos negócios', 'Aventureiros'],
    '.pc-copy': [
      '<h3>Estude melhor, não por mais tempo.</h3><div class="bub q">Me faz um quiz sobre a Revolução Francesa — pode pegar pesado.</div><div class="bub a"><b>P1.</b> Por que o Juramento do Jogo da Péla importou mais que a Queda da Bastilha? 🤔</div>',
      '<h3>Entregue antes do almoço.</h3><div class="bub q">Por que esse useEffect roda duas vezes?</div><div class="bub a">O Strict Mode executa os efeitos duas vezes em dev. Adicione um cleanup e pronto ✅</div>',
      '<h3>Nunca mais encare uma página em branco.</h3><div class="bub q">10 ganchos para um vídeo sobre brechó.</div><div class="bub a">1. “Gastei R$ 100 e me vesti como milionário por uma semana.”</div>',
      '<h3>Transforme 40 páginas em 4 linhas.</h3><div class="bub q">Resume essa apresentação do conselho pro meu gestor.</div><div class="bub a">Receita subiu 18%, churn estável, contratações pausadas até o T2. Um risco: custos de fornecedores.</div>',
      '<h3>Seu sócio 24 horas por dia.</h3><div class="bub q">Escreve uma placa para o nosso novo cardápio com leite de aveia.</div><div class="bub a">“O mesmo amor, um novo leite. Aveia-dorável 🌾”</div>',
      '<h3>Planos que saem do papel.</h3><div class="bub q">Viagem de carro para 7 amigos, 4 dias, barata.</div><div class="bub a">Fiz um roteiro com 2 lagos, 1 fonte termal e um chalé de $34 a noite 🏕️</div>'
    ],

    // Try it
    '.try .eyebrow': 'Prévia interativa',
    '.try .h2': 'Pergunte algo <em>difícil.</em>',
    '.try .lede': 'Escolha uma pergunta e veja o Sonot trabalhar. Esta é uma prévia roteirizada — a versão de verdade está no app.',
    '.prompt': ['Por que o céu é azul e o pôr do sol laranja?', 'Escreva um haicai sobre segunda-feira', 'Ache o bug no meu loop em Python', 'Treino de 20 min sem equipamento'],
    '.tw-badge': 'Prévia',

    // Download + footer
    '.dl-title': 'Baixe o <em>Sonot.</em>',
    '.download .lede': 'Grátis para começar. Pronto em menos de um minuto.',
    '.plat small': ['Apple silicon e Intel', 'Windows 10 e 11', '.AppImage · .deb', 'iPhone e iPad', 'Android 10+'],
    '.foot-maker small': 'Feito com obsessão por',
    '.foot-links a': ['Baixar', 'GitHub'],
    '#replayFilm': 'Rever o filme',
    '.foot-copy': '© 2026 Sonot. Todos os direitos reservados.'
  };

  /* Strings used from JavaScript */
  var STR = {
    en: {
      langBtn: 'PT', langLabel: 'Mudar para português',
      typer: 'Plan 3 days in Kyoto for under $800 ✈️',
      soundOn: 'Sound on', soundOff: 'Sound off', soundTap: 'Tap anywhere for sound',
      stream: 'November is maple season, so I built this around the best foliage at the quietest hours. Everything below is walkable or on one JR pass, with $58 to spare.',
      quick: 'Make this message sound friendlier',
      tones: [
        'Hey! Just checking in on the draft — no rush, whenever you get a sec. 😊',
        'Good afternoon. I wanted to follow up on the status of the draft at your convenience.',
        'Draft status? Need it Friday. Go. 🚀'
      ],
      askPlaceholder: 'Ask Sonot anything…', thinking: 'thinking…',
      downloadFor: 'Download for {os}',
      soon: 'Sonot for {os} is almost here. Downloads open soon ✨',
      answers: [
        {
          q: 'Why is the sky blue but sunsets orange?', ms: 'Thought for 2s',
          a: '<p>Sunlight carries every colour. When it hits air molecules, <b>short blue wavelengths scatter far more</b> than long red ones (roughly 5–6× more). That effect is called <b>Rayleigh scattering</b>.</p>' +
             '<ul><li><b>Midday:</b> light takes a short path through the air, so scattered blue reaches your eyes from every direction.</li>' +
             '<li><b>Sunset:</b> light crosses up to ~40× more atmosphere. Most of the blue is scattered away before it reaches you, leaving oranges and reds.</li></ul>' +
             '<p>Bonus: the sky isn\'t violet because your eyes are less sensitive to violet, and some of it is absorbed high up. 🌅</p>'
        },
        {
          q: 'Write a haiku about Mondays', ms: 'Thought for 1s',
          a: '<p class="haiku">Alarm clock again —<br>the coffee knows my sorrow,<br>Friday, far away.</p>' +
             '<p>Want a hopeful version? I can write a Monday that wins. ☕</p>'
        },
        {
          q: 'Find the bug: for i in range(len(xs)): print(xs[i + 1])', ms: 'Thought for 3s',
          a: '<p>On the last pass, <code>i</code> is <code>len(xs) - 1</code>, so <code>xs[i + 1]</code> reads past the end of the list and raises an <b>IndexError</b>.</p>' +
             '<p>To print every item, loop over the list directly:</p>' +
             '<pre><code>for x in xs:\n    print(x)</code></pre>' +
             '<p>If you really wanted each <i>next</i> item, pair them up:</p>' +
             '<pre><code>for cur, nxt in zip(xs, xs[1:]):\n    print(nxt)</code></pre>'
        },
        {
          q: 'Plan a 20-minute workout, no equipment', ms: 'Thought for 2s',
          a: '<p>Here\'s a <b>20-minute full-body circuit</b>: 40s work, 20s rest, 3 rounds.</p>' +
             '<ol><li><b>Jumping jacks</b>: warm up the engine</li><li><b>Squats</b>: slow down, fast up</li><li><b>Push-ups</b>: knees down is fine</li>' +
             '<li><b>Reverse lunges</b>: alternate legs</li><li><b>Plank shoulder taps</b>: keep hips steady</li><li><b>Mountain climbers</b>: finish strong</li></ol>' +
             '<p>6 moves × 1 min × 3 rounds = 18 min, plus a 2-minute cool-down stretch. You\'ve got this 💪</p>'
        }
      ]
    },
    pt: {
      langBtn: 'EN', langLabel: 'Switch to English',
      typer: 'Planeje 3 dias em Kyoto por menos de $800 ✈️',
      soundOn: 'Som ligado', soundOff: 'Som desligado', soundTap: 'Toque em qualquer lugar para ouvir',
      stream: 'Novembro é temporada de folhas vermelhas, então montei tudo em torno da melhor folhagem nos horários mais tranquilos. Dá para fazer tudo a pé ou com um único JR Pass, e ainda sobram $58.',
      quick: 'Deixe essa mensagem mais simpática',
      tones: [
        'Oi! Só passando pra saber do rascunho — sem pressa, quando puder. 😊',
        'Boa tarde. Gostaria de saber o andamento do rascunho, quando for conveniente.',
        'Rascunho? Preciso pra sexta. Bora. 🚀'
      ],
      askPlaceholder: 'Pergunte qualquer coisa ao Sonot…', thinking: 'pensando…',
      downloadFor: 'Baixar para {os}',
      soon: 'O Sonot para {os} está quase pronto. Os downloads abrem em breve ✨',
      version: 'v1.0 — prévia',
      req_mac: 'macOS 12 ou mais recente', req_win: 'Windows 10 ou mais recente', req_linux: 'Ubuntu 20.04+, Fedora 36+',
      req_ios: 'iOS 16 ou mais recente', req_android: 'Android 10 ou mais recente',
      answers: [
        {
          q: 'Por que o céu é azul, mas o pôr do sol é laranja?', ms: 'Pensou por 2s',
          a: '<p>A luz do sol tem todas as cores. Quando ela bate nas moléculas do ar, <b>os comprimentos de onda azuis, mais curtos, se espalham muito mais</b> que os vermelhos (umas 5 a 6 vezes mais). Esse efeito se chama <b>espalhamento de Rayleigh</b>.</p>' +
             '<ul><li><b>Meio-dia:</b> a luz faz um caminho curto pelo ar, então o azul espalhado chega aos seus olhos de todas as direções.</li>' +
             '<li><b>Pôr do sol:</b> a luz atravessa até ~40 vezes mais atmosfera. Quase todo o azul se espalha antes de chegar até você, sobrando os laranjas e vermelhos.</li></ul>' +
             '<p>Bônus: o céu não é violeta porque seus olhos são menos sensíveis ao violeta, e parte dele é absorvida lá no alto. 🌅</p>'
        },
        {
          q: 'Escreva um haicai sobre segunda-feira', ms: 'Pensou por 1s',
          a: '<p class="haiku">Segunda outra vez —<br>só o café me entende,<br>sexta tão distante.</p>' +
             '<p>Quer uma versão mais otimista? Posso escrever uma segunda-feira vitoriosa. ☕</p>'
        },
        {
          q: 'Ache o bug: for i in range(len(xs)): print(xs[i + 1])', ms: 'Pensou por 3s',
          a: '<p>Na última volta, <code>i</code> vale <code>len(xs) - 1</code>, então <code>xs[i + 1]</code> lê além do fim da lista e gera um <b>IndexError</b>.</p>' +
             '<p>Para imprimir todos os itens, percorra a lista direto:</p>' +
             '<pre><code>for x in xs:\n    print(x)</code></pre>' +
             '<p>Se você queria mesmo o <i>próximo</i> item de cada um, junte em pares:</p>' +
             '<pre><code>for cur, nxt in zip(xs, xs[1:]):\n    print(nxt)</code></pre>'
        },
        {
          q: 'Monte um treino de 20 minutos sem equipamento', ms: 'Pensou por 2s',
          a: '<p>Aqui vai um <b>circuito de corpo inteiro de 20 minutos</b>: 40s de exercício, 20s de descanso, 3 rodadas.</p>' +
             '<ol><li><b>Polichinelos</b>: aquece o motor</li><li><b>Agachamentos</b>: desce devagar, sobe rápido</li><li><b>Flexões</b>: pode apoiar os joelhos</li>' +
             '<li><b>Afundos para trás</b>: alterne as pernas</li><li><b>Prancha com toque no ombro</b>: quadril firme</li><li><b>Escalador</b>: termine com tudo</li></ol>' +
             '<p>6 exercícios × 1 min × 3 rodadas = 18 min, mais 2 minutos de alongamento no final. Você consegue 💪</p>'
        }
      ]
    }
  };

  var lang = 'en', listeners = [];

  function lastText(el) {
    for (var n = el.lastChild; n; n = n.previousSibling) if (n.nodeType === 3 && n.nodeValue.trim()) return n;
    return null;
  }

  function apply(next) {
    lang = next === 'pt' ? 'pt' : 'en';
    document.documentElement.lang = lang === 'pt' ? 'pt-BR' : 'en';
    Object.keys(PT).forEach(function (sel) {
      var v = PT[sel];
      Array.prototype.forEach.call(document.querySelectorAll(sel), function (el, i) {
        var val = Array.isArray(v) ? v[i] : v;
        if (val === undefined) return;
        if (val && typeof val === 'object') {
          var tn = lastText(el);
          if (!tn) return;
          if (tn._en === undefined) tn._en = tn.nodeValue;
          tn.nodeValue = lang === 'pt' ? ' ' + val.last : tn._en;
        } else {
          if (el._en === undefined) el._en = el.innerHTML;
          el.innerHTML = lang === 'pt' ? val : el._en;
        }
      });
    });
    listeners.forEach(function (f) { f(lang); });
  }

  window.SonotI18n = {
    apply: apply,
    get lang() { return lang; },
    t: function (k) { var d = STR[lang]; return d[k] !== undefined ? d[k] : STR.en[k]; },
    on: function (f) { listeners.push(f); }
  };
})();
