# Cyber Psicólogo — protótipo de hackathon (Godot 4)

Minigame estilo *Trouble at the National Neopian* com tema **glitch**.
Você é um cyber psicólogo tratando os glitches do cérebro do paciente.

- **Lado ESQUERDO do cérebro** → teclas **S D F**
- **Lado DIREITO do cérebro** → teclas **J K L**
- **Co-op local (a inovação):** um jogador cuida do SDF, outro do JKL, no mesmo teclado. Já funciona, sem código extra.

---

## Como rodar
1. Instale o **Godot 4.x** (4.3+ recomendado).
2. Abra o Godot → **Importar** → selecione o arquivo `project.godot` desta pasta.
3. Aperte **F5** (rodar). Pronto.

## Loop do jogo (v3)
1. **Área da mente** (nível): trate a quota de glitches sem deixar o COLAPSO encher.
2. **Decisão clínica**: aparece uma anotação do caso de João com 2-3 escolhas. Aperte **1 / 2 / 3**.
3. A escolha **inclina o diagnóstico** (Ansiedade / Trauma / Autoimagem) e dá um **power-up** (modifica o gameplay).
4. Próxima área, mais difícil. Ao fim das 4 áreas → tela de **diagnóstico provável**.

## Como jogar
- Glitches aparecem nas 6 colunas. Cada um tem um **anel de perigo** que vai fechando.
- Aperte a **tecla da coluna** pra tratar o glitch antes do anel fechar.
- Glitch perdido → sobe o **RISCO DE COLAPSO**. Encheu = fim de jogo.
- Tratar em sequência aumenta o **COMBO** (multiplica o score).
- Cada glitch tem uma **VOZ INTERIOR** (pensamento intrusivo) no painel central. Ao tratar, ele é **ressignificado** numa frase mais gentil — esse é o coração do tema "você não apaga, você integra".
- **RAIVA** (laranja): NÃO se trata com toque — **SEGURE** a tecla pra "respirar junto" e baixar a escalação (anel azul interno enche). É o gesto de de-escalada.
- **TRAUMA** (verde) precisa de 2 toques. **VAZIO** (cinza) é lento. **DISTORÇÃO** (amarelo) treme na tela.

> A ideia da v2: o **gesto** combina com a emoção. Próximos passos sugeridos — Medo congela a coluna vizinha; Trauma vira press no tempo certo (timing, não velocidade); Vazio vira vários toques leves; Distorção mostra a tecla errada de propósito.

---

## Como dividir entre 5 pessoas (mínimo de conflito no git)
O projeto foi feito de propósito quase todo em código (poucos arquivos `.tscn`) pra evitar dor de cabeça com merge de cena no git.

| Pessoa | Arquivo / área | Tarefa |
|---|---|---|
| 1 (líder) | `scripts/Main.gd` | game loop, dificuldade, score, colapso |
| 2 | `scripts/Glitch.gd` | comportamento dos tipos de glitch (novas mecânicas) |
| 3 | arte (pasta `art/`) | trocar os círculos desenhados por sprites/pixel art |
| 4 | áudio | adicionar `AudioStreamPlayer` para acerto/erro/música |
| 5 | UI/UX + telas | tela inicial, tela de game over bonita, tutorial |

Dica: combinem que **só a pessoa 1 mexe no `Main.gd`**. As outras criam arquivos novos e o líder integra. Isso evita 90% dos conflitos.

---

## Ideias de extensão (ordem de "ganho rápido")
1. **Som** — o que mais aumenta a sensação de "jogo pronto". 3 sons: tratar, errar, colapso.
2. **Glitch que se espalha** — CULPA: se não tratar, contamina a lane vizinha. (mexe em `Glitch.gd` + `Main.gd`)
3. **Modo "chama o colega"** — quando os 6 slots enchem, pisca "SOCORRO LADO DIREITO!" pra puxar a outra pessoa. Já dá pra fazer só com texto.
4. **Sequência de teclas** — DISTORÇÃO mostra a tecla errada de propósito; o jogador tem que ignorar e apertar a da coluna.
5. **Export pra Web (HTML5)** — pra demo do hackathon rodar no navegador: Projeto → Exportar → Web. (o renderer já está em GL Compatibility justamente pra isso)

## Onde mexer pra balancear (no topo do `Main.gd`)
- `spawn_inicial` — mais alto = mais fácil no começo
- `spawn_minimo` — limite de quão frenético fica
- `escalacao_base` — velocidade que os glitches pioram
- `dano_colapso` — punição por glitch perdido
# Gamejam42
