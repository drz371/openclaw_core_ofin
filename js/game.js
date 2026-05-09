const TILE_SIZE = 32;
const MAP_COLS = 25;
const MAP_ROWS = 19;

const TILE = {
  GRASS: 0,
  GRASS_DARK: 1,
  PATH: 2,
  WATER: 3,
  TREE: 4,
  HOUSE_WALL: 5,
  HOUSE_DOOR: 6,
  HOUSE_ROOF: 7,
  CHEST: 8,
  SIGN: 9,
  FENCE: 10,
  FLOWER: 11,
  BRIDGE: 12,
  MOUNTAIN: 13,
  CAVE: 14,
  CASTLE_WALL: 15,
  CASTLE_DOOR: 16
};

const WORLD_MAP = [
  [13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13],
  [13,0,0,0,13,0,0,0,0,0,0,0,0,0,0,0,0,0,13,4,0,0,0,13,13],
  [13,0,11,0,13,0,0,0,0,0,0,0,0,0,0,0,0,0,13,0,0,0,0,0,13],
  [13,0,0,0,13,0,0,0,0,0,0,0,0,0,0,0,0,0,13,0,0,0,0,0,13],
  [13,0,0,0,0,0,0,4,0,0,0,0,0,0,0,4,0,0,13,0,0,4,0,13,13],
  [13,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,13,13],
  [13,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,13],
  [13,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,13],
  [13,2,15,15,15,15,15,2,2,2,0,0,0,0,0,0,0,0,0,0,4,0,0,2,13],
  [13,2,15,16,15,15,15,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,2,13],
  [13,2,15,15,15,15,15,2,2,2,0,0,4,0,0,0,0,4,0,0,0,0,0,2,13],
  [13,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,2,13],
  [13,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,2,13],
  [13,0,0,0,0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,13],
  [13,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,13],
  [13,0,0,4,0,0,0,0,0,0,0,0,3,3,3,0,0,0,0,0,0,0,0,0,13],
  [13,0,0,0,0,0,0,0,0,0,0,0,3,14,3,0,0,0,0,4,0,0,0,0,13],
  [13,0,0,0,0,0,0,0,0,0,0,0,3,3,3,0,0,0,0,0,0,0,0,0,13],
  [13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13],
];

const ENCOUNTER_TILES = [TILE.GRASS, TILE.GRASS_DARK];

const PIXEL_COLORS = {
  skin: '#f5c5a3',
  skinDark: '#d4a574',
  hair: '#5b3a1a',
  hairDark: '#3d2510',
  armor: '#4488cc',
  armorDark: '#336699',
  armorLight: '#66aadd',
  pants: '#445577',
  pantsDark: '#334466',
  boots: '#553322',
  sword: '#dddddd',
  swordDark: '#999999',
  swordLight: '#ffffff',
  shield: '#ccaa44',
  shieldDark: '#aa8833',
  
  slime: '#44cc88',
  slimeDark: '#33aa66',
  slimeLight: '#66eeaa',
  
  skeleton: '#ddddcc',
  skeletonDark: '#aaaabb',
  skeletonEye: '#ff4444',
  
  mage: '#7733cc',
  mageDark: '#5522aa',
  mageLight: '#9955dd',
  mageSkin: '#eeddcc',
  
  dragon: '#cc2244',
  dragonDark: '#aa1133',
  dragonLight: '#ee4466',
  dragonWing: '#881122',
  dragonHorn: '#ffcc00',
  
  grass: '#55aa44',
  grassDark: '#449933',
  grassLight: '#66bb55',
  
  path: '#ccaa77',
  pathDark: '#bb9966',
  
  water: '#3388cc',
  waterDark: '#226699',
  waterLight: '#44aadd',
  
  tree: '#338822',
  treeDark: '#226611',
  treeLight: '#44aa33',
  treeTrunk: '#886644',
  treeTrunkDark: '#664433',
  
  house: '#cc8844',
  houseDark: '#aa6633',
  houseLight: '#eeaa66',
  door: '#884422',
  roof: '#cc3333',
  roofDark: '#aa2222',
  roofLight: '#ee4444',
  
  chest: '#ddaa33',
  chestDark: '#bb8822',
  chestLight: '#ffcc44',
  
  sign: '#aa8844',
  signDark: '#886633',
  signPost: '#886644',
  
  fence: '#ccaa66',
  fenceDark: '#aa8844',
  
  flower: ['#ff66aa', '#ffaa33', '#ff4444', '#aa66ff', '#ffffff'],
  
  bridge: '#aa7744',
  bridgeDark: '#885533',
  
  mountain: '#887766',
  mountainDark: '#665544',
  mountainLight: '#aa9988',
  
  cave: '#555566',
  caveDark: '#444455',
  caveLight: '#666677',
  
  castle: '#9988aa',
  castleDark: '#776688',
  castleLight: '#bbaacc',
};

class PixelGame {
  constructor() {
    this.canvas = document.getElementById('gameCanvas');
    this.ctx = this.canvas.getContext('2d');
    this.overlay = document.getElementById('gameOverlay');
    this.overlayTitle = document.getElementById('overlayTitle');
    this.overlayMessage = document.getElementById('overlayMessage');
    this.startBtn = document.getElementById('startGameBtn');
    this.logContent = document.getElementById('logContent');
    
    this.player = {
      x: 10,
      y: 10,
      dir: 2,
      frame: 0,
      moving: false,
      name: '勇者',
      level: 1,
      hp: 50,
      maxHp: 50,
      mp: 20,
      maxMp: 20,
      atk: 12,
      def: 8,
      exp: 0,
      expToLevel: 50,
      potions: 3,
      gold: 0,
      isDefending: false,
      walkFrame: 0,
      walkTimer: 0
    };
    
    this.camera = { x: 0, y: 0 };
    this.monsters = [
      { name: '史莱姆', hp: 30, maxHp: 30, atk: 5, exp: 10, skill: '分裂', color: PIXEL_COLORS.slime, difficulty: 1 },
      { name: '骷髅战士', hp: 60, maxHp: 60, atk: 12, exp: 25, skill: '骨刃', color: PIXEL_COLORS.skeleton, difficulty: 2 },
      { name: '暗影法师', hp: 45, maxHp: 45, atk: 18, exp: 35, skill: '暗影箭', color: PIXEL_COLORS.mage, difficulty: 3 },
      { name: '巨龙', hp: 150, maxHp: 150, atk: 25, exp: 100, skill: '龙息', color: PIXEL_COLORS.dragon, difficulty: 4 }
    ];
    
    this.currentMonster = null;
    this.isBattling = false;
    this.isPlayerTurn = true;
    this.gameStarted = false;
    this.battleAnim = { type: null, frame: 0, maxFrame: 15 };
    this.particles = [];
    this.time = 0;
    this.keys = {};
    this.moveTimer = 0;
    this.moveDelay = 12;
    this.npcs = [
      { x: 12, y: 8, dir: 2, name: '村长', dialogue: ['欢迎来到勇者村!', '北边的洞穴有怪物出没...', '小心草地上的怪物!', '去城堡找国王领取任务吧!'], dialogueIndex: 0 },
      { x: 8, y: 13, dir: 0, name: '商人', dialogue: ['要买点药水吗?', '我这里有最好的装备!', '祝你冒险顺利!'], dialogueIndex: 0, isMerchant: true },
      { x: 18, y: 10, dir: 1, name: '村民', dialogue: ['听说洞穴深处有宝藏!', '勇者大人加油!', '村东边的草地有很多史莱姆...'], dialogueIndex: 0 }
    ];
    
    this.showingDialogue = false;
    this.currentDialogue = [];
    this.dialogueIndex = 0;
    this.showingSign = false;
    this.signText = '';
    this.encounterCooldown = 0;
    this.battleVictory = false;
    this.battleDefeat = false;
    
    this.initCanvas();
    this.bindEvents();
    this.startBtn.addEventListener('click', () => this.startGame());
    this.startRenderLoop();
  }
  
  initCanvas() {
    const wrapper = this.canvas.parentElement;
    const rect = wrapper.getBoundingClientRect();
    const w = Math.max(rect.width * 2, 800);
    const h = Math.max(rect.height * 2, 600);
    this.canvas.width = w;
    this.canvas.height = h;
    this.viewCols = Math.floor(w / 2 / TILE_SIZE);
    this.viewRows = Math.floor(h / 2 / TILE_SIZE);
  }
  
  bindEvents() {
    document.addEventListener('keydown', (e) => {
      this.keys[e.key] = true;
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', ' '].includes(e.key)) {
        e.preventDefault();
      }
      if (e.key === ' ' || e.key === 'Enter') {
        if (this.showingDialogue) {
          this.nextDialogue();
        } else if (this.showingSign) {
          this.showingSign = false;
        } else if (this.isBattling && this.isPlayerTurn) {
        } else if (!this.isBattling && this.gameStarted) {
          this.interact();
        }
      }
    });
    
    document.addEventListener('keyup', (e) => {
      this.keys[e.key] = false;
    });
    
    document.querySelectorAll('.action-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        if (!this.isBattling || !this.isPlayerTurn) return;
        this.battleAction(btn.dataset.action);
      });
    });
  }
  
  startGame() {
    this.gameStarted = true;
    this.overlay.classList.add('hidden');
    this.logContent.innerHTML = '';
    this.addLog('冒险开始了! 使用方向键/WASD移动', 'system');
    this.addLog('按空格键与NPC对话或调查物品', 'system');
    this.updatePlayerUI();
  }
  
  interact() {
    const dx = [0, 0, -1, 1];
    const dy = [-1, 1, 0, 0];
    const tx = this.player.x + dx[this.player.dir];
    const ty = this.player.y + dy[this.player.dir];
    
    for (const npc of this.npcs) {
      if (npc.x === tx && npc.y === ty) {
        this.showingDialogue = true;
        this.currentDialogue = npc.dialogue;
        this.dialogueIndex = npc.dialogueIndex;
        return;
      }
    }
    
    const tile = WORLD_MAP[ty]?.[tx];
    if (tile === TILE.SIGN) {
      this.showingSign = true;
      this.signText = '公告：北边洞穴危险，勇者请做好准备!';
    }
  }
  
  nextDialogue() {
    this.dialogueIndex++;
    if (this.dialogueIndex >= this.currentDialogue.length) {
      this.showingDialogue = false;
      for (const npc of this.npcs) {
        if (npc.dialogueIndex < npc.dialogue.length - 1) {
          npc.dialogueIndex++;
        }
      }
    }
  }
  
  canMove(x, y) {
    if (x < 0 || x >= MAP_COLS || y < 0 || y >= MAP_ROWS) return false;
    const tile = WORLD_MAP[y][x];
    const blocked = [TILE.WATER, TILE.TREE, TILE.HOUSE_WALL, TILE.HOUSE_ROOF, TILE.MOUNTAIN, TILE.CASTLE_WALL];
    return !blocked.includes(tile);
  }
  
  update() {
    this.time++;
    if (this.showingDialogue || this.showingSign || this.isBattling) return;
    
    if (this.moveTimer > 0) {
      this.moveTimer--;
      return;
    }
    
    let dx = 0, dy = 0;
    let newDir = this.player.dir;
    
    if (this.keys['ArrowUp'] || this.keys['w'] || this.keys['W']) { dy = -1; newDir = 0; }
    else if (this.keys['ArrowDown'] || this.keys['s'] || this.keys['S']) { dy = 1; newDir = 1; }
    else if (this.keys['ArrowLeft'] || this.keys['a'] || this.keys['A']) { dx = -1; newDir = 2; }
    else if (this.keys['ArrowRight'] || this.keys['d'] || this.keys['D']) { dx = 1; newDir = 3; }
    
    if (dx !== 0 || dy !== 0) {
      this.player.dir = newDir;
      const nx = this.player.x + dx;
      const ny = this.player.y + dy;
      
      if (this.canMove(nx, ny)) {
        this.player.x = nx;
        this.player.y = ny;
        this.player.moving = true;
        this.player.walkTimer++;
        if (this.player.walkTimer % 4 === 0) {
          this.player.walkFrame = (this.player.walkFrame + 1) % 4;
        }
        this.moveTimer = this.moveDelay;
        
        if (this.encounterCooldown > 0) {
          this.encounterCooldown--;
        }
        
        const tile = WORLD_MAP[ny][nx];
        if (ENCOUNTER_TILES.includes(tile) && this.encounterCooldown === 0) {
          if (Math.random() < 0.12) {
            this.startRandomEncounter();
          }
        }
      }
    } else {
      this.player.moving = false;
      this.player.walkFrame = 0;
    }
    
    this.camera.x = this.player.x - Math.floor(this.viewCols / 2);
    this.camera.y = this.player.y - Math.floor(this.viewRows / 2);
    this.camera.x = Math.max(0, Math.min(MAP_COLS - this.viewCols, this.camera.x));
    this.camera.y = Math.max(0, Math.min(MAP_ROWS - this.viewRows, this.camera.y));
  }
  
  startRandomEncounter() {
    const possibleMonsters = this.monsters.filter(m => {
      if (m.difficulty === 1) return true;
      if (m.difficulty === 2) return this.player.level >= 2;
      if (m.difficulty === 3) return this.player.level >= 4;
      if (m.difficulty === 4) return this.player.level >= 6;
      return false;
    });
    
    const weights = possibleMonsters.map(m => Math.max(1, 5 - m.difficulty));
    const totalWeight = weights.reduce((a, b) => a + b, 0);
    let rand = Math.random() * totalWeight;
    let chosen = possibleMonsters[0];
    
    for (let i = 0; i < possibleMonsters.length; i++) {
      rand -= weights[i];
      if (rand <= 0) {
        chosen = possibleMonsters[i];
        break;
      }
    }
    
    this.currentMonster = { ...chosen };
    this.isBattling = true;
    this.isPlayerTurn = true;
    this.player.isDefending = false;
    this.enableActionButtons(true);
    
    this.addLog(`${this.currentMonster.name} 出现了!`, 'system');
  }
  
  battleAction(action) {
    if (!this.isPlayerTurn || !this.isBattling) return;
    this.isPlayerTurn = false;
    this.player.isDefending = false;
    this.enableActionButtons(false);
    
    switch (action) {
      case 'attack': {
        this.battleAnim = { type: 'playerAttack', frame: 0, maxFrame: 15 };
        setTimeout(() => {
          const dmg = Math.max(1, this.player.atk + Math.floor(Math.random() * 6) - 3);
          this.currentMonster.hp = Math.max(0, this.currentMonster.hp - dmg);
          this.addLog(`勇者攻击! 造成 ${dmg} 点伤害`, 'player');
          this.battleAnim = { type: 'hit', frame: 0, maxFrame: 10 };
          this.updateMonsterUI();
          setTimeout(() => this.checkBattleEnd(), 500);
        }, 300);
        break;
      }
      case 'magic': {
        if (this.player.mp < 5) {
          this.addLog('MP不足!', 'system');
          this.isPlayerTurn = true;
          this.enableActionButtons(true);
          return;
        }
        this.player.mp -= 5;
        this.battleAnim = { type: 'magic', frame: 0, maxFrame: 20 };
        setTimeout(() => {
          const dmg = Math.max(1, this.player.atk * 2 + Math.floor(Math.random() * 10) - 5);
          this.currentMonster.hp = Math.max(0, this.currentMonster.hp - dmg);
          this.addLog(`火焰魔法! 造成 ${dmg} 点伤害`, 'player');
          this.battleAnim = { type: 'hit', frame: 0, maxFrame: 10 };
          this.updateMonsterUI();
          this.updatePlayerUI();
          setTimeout(() => this.checkBattleEnd(), 500);
        }, 500);
        break;
      }
      case 'heal': {
        if (this.player.mp < 8) {
          this.addLog('MP不足!', 'system');
          this.isPlayerTurn = true;
          this.enableActionButtons(true);
          return;
        }
        this.player.mp -= 8;
        this.battleAnim = { type: 'heal', frame: 0, maxFrame: 15 };
        setTimeout(() => {
          const heal = 25 + Math.floor(Math.random() * 10);
          this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal);
          this.addLog(`治疗恢复了 ${heal} HP`, 'heal');
          this.updatePlayerUI();
          this.enemyTurn();
        }, 400);
        return;
      }
      case 'defend': {
        this.player.isDefending = true;
        this.addLog('勇者进行防御!', 'player');
        this.enemyTurn();
        return;
      }
      case 'item': {
        if (this.player.potions <= 0) {
          this.addLog('没有药水了!', 'system');
          this.isPlayerTurn = true;
          this.enableActionButtons(true);
          return;
        }
        this.player.potions--;
        this.battleAnim = { type: 'heal', frame: 0, maxFrame: 15 };
        setTimeout(() => {
          this.player.hp = Math.min(this.player.maxHp, this.player.hp + 40);
          this.addLog(`使用药水恢复了 40 HP`, 'heal');
          this.updatePlayerUI();
          this.enemyTurn();
        }, 400);
        return;
      }
    }
    
    setTimeout(() => {
      if (this.currentMonster && this.currentMonster.hp > 0) {
        this.enemyTurn();
      }
    }, 1000);
  }
  
  enemyTurn() {
    setTimeout(() => {
      this.battleAnim = { type: 'enemyAttack', frame: 0, maxFrame: 15 };
      setTimeout(() => {
        let dmg = this.currentMonster.atk + Math.floor(Math.random() * 6) - 3;
        const useSkill = Math.random() < 0.3;
        if (useSkill) {
          dmg = Math.floor(dmg * 1.5);
          this.addLog(`${this.currentMonster.name} 使用 ${this.currentMonster.skill}!`, 'enemy');
        }
        if (this.player.isDefending) dmg = Math.floor(dmg * 0.5);
        dmg = Math.max(1, dmg - Math.floor(this.player.def * 0.5));
        this.player.hp = Math.max(0, this.player.hp - dmg);
        this.addLog(`受到 ${dmg} 点伤害!`, 'enemy');
        this.battleAnim = { type: 'hit', frame: 0, maxFrame: 10 };
        this.updatePlayerUI();
        
        if (this.player.hp <= 0) {
          this.addLog('勇者被击败了...', 'system');
          this.isBattling = false;
          this.battleDefeat = true;
          this.showBattleOverlay('战败', '你被怪物击败了...');
          return;
        }
        
        this.isPlayerTurn = true;
        this.enableActionButtons(true);
      }, 400);
    }, 500);
  }
  
  checkBattleEnd() {
    if (!this.currentMonster || this.currentMonster.hp <= 0) {
      this.addLog(`${this.currentMonster.name} 被击败了!`, 'system');
      this.player.exp += this.currentMonster.exp;
      this.addLog(`获得 ${this.currentMonster.exp} 经验值`, 'system');
      this.player.gold += this.currentMonster.exp * 2;
      
      if (this.player.exp >= this.player.expToLevel) {
        this.player.level++;
        this.player.exp -= this.player.expToLevel;
        this.player.expToLevel = Math.floor(this.player.expToLevel * 1.5);
        this.player.maxHp += 15;
        this.player.hp = this.player.maxHp;
        this.player.maxMp += 8;
        this.player.mp = this.player.maxMp;
        this.player.atk += 4;
        this.player.def += 3;
        this.addLog(`升级! 达到 Lv.${this.player.level}!`, 'system');
        this.battleAnim = { type: 'levelUp', frame: 0, maxFrame: 40 };
      }
      
      this.updatePlayerUI();
      this.battleVictory = true;
      
      setTimeout(() => {
        this.isBattling = false;
        this.battleVictory = false;
        this.encounterCooldown = 5;
        this.enableActionButtons(true);
      }, 1500);
    }
  }
  
  showBattleOverlay(title, message) {
    this.overlayTitle.textContent = title;
    this.overlayMessage.textContent = message;
    this.startBtn.textContent = '重新开始';
    this.overlay.classList.remove('hidden');
    this.gameStarted = false;
  }
  
  updatePlayerUI() {
    const el = (id) => document.getElementById(id);
    if (!el('playerLevel')) return;
    el('playerLevel').textContent = `Lv.${this.player.level}`;
    el('playerHp').textContent = `${this.player.hp}/${this.player.maxHp}`;
    el('playerHpBar').style.width = `${(this.player.hp / this.player.maxHp) * 100}%`;
    el('playerMp').textContent = `${this.player.mp}/${this.player.maxMp}`;
    el('playerMpBar').style.width = `${(this.player.mp / this.player.maxMp) * 100}%`;
    el('playerExp').textContent = `${this.player.exp}/${this.player.expToLevel}`;
    el('playerExpBar').style.width = `${(this.player.exp / this.player.expToLevel) * 100}%`;
    el('playerAtk').textContent = this.player.atk;
    el('playerDef').textContent = this.player.def;
    el('potionCount').textContent = this.player.potions;
  }
  
  updateMonsterUI() {
  }
  
  enableActionButtons(enabled) {
    document.querySelectorAll('.action-btn').forEach(btn => btn.disabled = !enabled);
  }
  
  addLog(message, type) {
    if (!this.logContent) return;
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    entry.textContent = message;
    this.logContent.appendChild(entry);
    this.logContent.scrollTop = this.logContent.scrollHeight;
  }
  
  px(ctx, x, y, size, color) {
    ctx.fillStyle = color;
    ctx.fillRect(Math.floor(x), Math.floor(y), size, size);
  }
  
  drawTile(ctx, tile, sx, sy, ts) {
    switch (tile) {
      case TILE.GRASS: {
        ctx.fillStyle = PIXEL_COLORS.grass;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.grassDark;
        for (let i = 0; i < 3; i++) {
          const gx = ((sx * 7 + i * 13) % ts);
          const gy = ((sy * 11 + i * 17) % ts);
          ctx.fillRect(sx + gx, sy + gy, 2, 3);
        }
        break;
      }
      case TILE.GRASS_DARK: {
        ctx.fillStyle = PIXEL_COLORS.grassDark;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.grass;
        for (let i = 0; i < 2; i++) {
          const gx = ((sx * 9 + i * 11) % ts);
          const gy = ((sy * 7 + i * 19) % ts);
          ctx.fillRect(sx + gx, sy + gy, 2, 2);
        }
        break;
      }
      case TILE.PATH: {
        ctx.fillStyle = PIXEL_COLORS.path;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.pathDark;
        for (let i = 0; i < 4; i++) {
          const px = ((sx * 3 + i * 7) % ts);
          const py = ((sy * 5 + i * 13) % ts);
          ctx.fillRect(sx + px, sy + py, 2, 2);
        }
        break;
      }
      case TILE.WATER: {
        const wave = Math.sin(this.time * 0.05 + sx * 0.1) * 0.1;
        ctx.fillStyle = PIXEL_COLORS.water;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.waterLight;
        ctx.fillRect(sx + 4 + Math.floor(wave * 4), sy + 8, 8, 2);
        ctx.fillRect(sx + 12 - Math.floor(wave * 4), sy + 18, 6, 2);
        break;
      }
      case TILE.TREE: {
        ctx.fillStyle = PIXEL_COLORS.grass;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.treeTrunk;
        ctx.fillRect(sx + 13, sy + 16, 6, 16);
        ctx.fillStyle = PIXEL_COLORS.treeTrunkDark;
        ctx.fillRect(sx + 15, sy + 16, 2, 16);
        ctx.fillStyle = PIXEL_COLORS.tree;
        ctx.fillRect(sx + 4, sy + 2, 24, 18);
        ctx.fillStyle = PIXEL_COLORS.treeDark;
        ctx.fillRect(sx + 8, sy + 6, 4, 4);
        ctx.fillStyle = PIXEL_COLORS.treeLight;
        ctx.fillRect(sx + 16, sy + 4, 4, 4);
        ctx.fillRect(sx + 6, sy + 10, 4, 4);
        break;
      }
      case TILE.HOUSE_WALL: {
        ctx.fillStyle = PIXEL_COLORS.house;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.houseDark;
        ctx.fillRect(sx, sy, ts, 2);
        ctx.fillRect(sx, sy, 2, ts);
        break;
      }
      case TILE.HOUSE_DOOR: {
        ctx.fillStyle = PIXEL_COLORS.house;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.door;
        ctx.fillRect(sx + 10, sy + 8, 12, 24);
        ctx.fillStyle = PIXEL_COLORS.chestLight;
        ctx.fillRect(sx + 19, sy + 18, 3, 3);
        break;
      }
      case TILE.HOUSE_ROOF: {
        ctx.fillStyle = PIXEL_COLORS.roof;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.roofDark;
        ctx.fillRect(sx + Math.floor((sx + sy) * 0.3) % 8, sy + Math.floor((sx + sy) * 0.5) % 8, 4, 4);
        break;
      }
      case TILE.CHEST: {
        ctx.fillStyle = PIXEL_COLORS.grass;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.chest;
        ctx.fillRect(sx + 6, sy + 10, 20, 16);
        ctx.fillStyle = PIXEL_COLORS.chestDark;
        ctx.fillRect(sx + 6, sy + 10, 20, 4);
        ctx.fillStyle = PIXEL_COLORS.chestLight;
        ctx.fillRect(sx + 14, sy + 16, 4, 4);
        break;
      }
      case TILE.SIGN: {
        ctx.fillStyle = PIXEL_COLORS.grass;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.signPost;
        ctx.fillRect(sx + 14, sy + 12, 4, 20);
        ctx.fillStyle = PIXEL_COLORS.sign;
        ctx.fillRect(sx + 6, sy + 4, 20, 12);
        ctx.fillStyle = PIXEL_COLORS.signDark;
        ctx.fillRect(sx + 8, sy + 6, 16, 8);
        break;
      }
      case TILE.FENCE: {
        ctx.fillStyle = PIXEL_COLORS.grass;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.fence;
        ctx.fillRect(sx + 2, sy + 4, 4, 28);
        ctx.fillRect(sx + 14, sy + 4, 4, 28);
        ctx.fillRect(sx, sy + 8, ts, 4);
        ctx.fillRect(sx, sy + 20, ts, 4);
        ctx.fillStyle = PIXEL_COLORS.fenceDark;
        ctx.fillRect(sx + 2, sy + 4, 2, 28);
        ctx.fillRect(sx + 14, sy + 4, 2, 28);
        break;
      }
      case TILE.FLOWER: {
        ctx.fillStyle = PIXEL_COLORS.grass;
        ctx.fillRect(sx, sy, ts, ts);
        const fi = (sx + sy) % PIXEL_COLORS.flower.length;
        ctx.fillStyle = PIXEL_COLORS.flower[fi];
        ctx.fillRect(sx + 8, sy + 8, 4, 4);
        ctx.fillRect(sx + 20, sy + 14, 4, 4);
        ctx.fillRect(sx + 14, sy + 22, 4, 4);
        ctx.fillStyle = '#44aa33';
        ctx.fillRect(sx + 9, sy + 12, 2, 6);
        ctx.fillRect(sx + 21, sy + 18, 2, 6);
        break;
      }
      case TILE.BRIDGE: {
        ctx.fillStyle = PIXEL_COLORS.water;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.bridge;
        ctx.fillRect(sx + 2, sy + 2, 28, 28);
        ctx.fillStyle = PIXEL_COLORS.bridgeDark;
        ctx.fillRect(sx + 2, sy + 2, 28, 3);
        ctx.fillRect(sx + 2, sy + 27, 28, 3);
        for (let i = 0; i < 3; i++) {
          ctx.fillRect(sx + 4 + i * 10, sy + 4, 2, 24);
        }
        break;
      }
      case TILE.MOUNTAIN: {
        ctx.fillStyle = PIXEL_COLORS.mountain;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.mountainDark;
        ctx.fillRect(sx + 4, sy + 12, 24, 20);
        ctx.fillStyle = PIXEL_COLORS.mountainLight;
        ctx.fillRect(sx + 8, sy + 4, 16, 12);
        ctx.fillRect(sx + 12, sy + 2, 8, 6);
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(sx + 12, sy + 2, 8, 4);
        break;
      }
      case TILE.CAVE: {
        ctx.fillStyle = PIXEL_COLORS.grass;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.cave;
        ctx.fillRect(sx + 2, sy + 6, 28, 26);
        ctx.fillStyle = PIXEL_COLORS.caveDark;
        ctx.fillRect(sx + 8, sy + 16, 16, 16);
        ctx.fillStyle = PIXEL_COLORS.caveLight;
        ctx.fillRect(sx + 4, sy + 6, 24, 4);
        break;
      }
      case TILE.CASTLE_WALL: {
        ctx.fillStyle = PIXEL_COLORS.castle;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.castleDark;
        ctx.fillRect(sx, sy, ts, 2);
        ctx.fillRect(sx, sy + 16, ts, 2);
        ctx.fillRect(sx, sy, 2, ts);
        break;
      }
      case TILE.CASTLE_DOOR: {
        ctx.fillStyle = PIXEL_COLORS.castle;
        ctx.fillRect(sx, sy, ts, ts);
        ctx.fillStyle = PIXEL_COLORS.door;
        ctx.fillRect(sx + 10, sy, 12, ts);
        ctx.fillStyle = PIXEL_COLORS.chestLight;
        ctx.fillRect(sx + 10, sy + 14, 3, 3);
        break;
      }
    }
  }
  
  drawPixelPlayer(ctx, px, py, size, frame, dir) {
    const s = size;
    const walk = frame % 2 === 1 ? Math.sin(this.time * 0.3) * 2 : 0;
    
    if (dir === 1) {
      this.px(ctx, px + 8, py, 16, PIXEL_COLORS.hair);
      this.px(ctx, px + 6, py + 4, 20, PIXEL_COLORS.hair);
      this.px(ctx, px + 8, py + 8, 16, PIXEL_COLORS.skin);
      this.px(ctx, px + 6, py + 12, 8, PIXEL_COLORS.skin);
      this.px(ctx, px + 18, py + 12, 8, PIXEL_COLORS.skin);
      this.px(ctx, px + 8, py + 16, 16, PIXEL_COLORS.armor);
      this.px(ctx, px + 6, py + 20, 20, PIXEL_COLORS.armor);
      this.px(ctx, px + 8, py + 24, 6, PIXEL_COLORS.pants);
      this.px(ctx, px + 18, py + 24, 6, PIXEL_COLORS.pants);
      this.px(ctx, px + 8, py + 28 + walk, 6, PIXEL_COLORS.boots);
      this.px(ctx, px + 18, py + 28 - walk, 6, PIXEL_COLORS.boots);
    } else if (dir === 0) {
      this.px(ctx, px + 8, py, 16, PIXEL_COLORS.hair);
      this.px(ctx, px + 6, py + 2, 20, PIXEL_COLORS.hair);
      this.px(ctx, px + 6, py + 6, 20, PIXEL_COLORS.hair);
      this.px(ctx, px + 8, py + 10, 16, PIXEL_COLORS.armor);
      this.px(ctx, px + 6, py + 14, 20, PIXEL_COLORS.armor);
      this.px(ctx, px + 8, py + 20, 16, PIXEL_COLORS.armorDark);
      this.px(ctx, px + 8, py + 24, 6, PIXEL_COLORS.pants);
      this.px(ctx, px + 18, py + 24, 6, PIXEL_COLORS.pants);
      this.px(ctx, px + 8, py + 28 + walk, 6, PIXEL_COLORS.boots);
      this.px(ctx, px + 18, py + 28 - walk, 6, PIXEL_COLORS.boots);
    } else if (dir === 2) {
      this.px(ctx, px + 10, py, 12, PIXEL_COLORS.hair);
      this.px(ctx, px + 8, py + 4, 16, PIXEL_COLORS.hair);
      this.px(ctx, px + 12, py + 8, 8, PIXEL_COLORS.skin);
      this.px(ctx, px + 10, py + 12, 6, PIXEL_COLORS.skin);
      this.px(ctx, px + 10, py + 16, 12, PIXEL_COLORS.armor);
      this.px(ctx, px + 6, py + 14, 6, PIXEL_COLORS.shield);
      this.px(ctx, px + 22, py + 10, 4, PIXEL_COLORS.armorLight);
      this.px(ctx, px + 10, py + 20, 12, PIXEL_COLORS.armorDark);
      this.px(ctx, px + 10, py + 24, 4, PIXEL_COLORS.pants);
      this.px(ctx, px + 18, py + 24, 4, PIXEL_COLORS.pants);
      this.px(ctx, px + 10, py + 28 + walk, 4, PIXEL_COLORS.boots);
      this.px(ctx, px + 18, py + 28 - walk, 4, PIXEL_COLORS.boots);
    } else {
      this.px(ctx, px + 10, py, 12, PIXEL_COLORS.hair);
      this.px(ctx, px + 8, py + 4, 16, PIXEL_COLORS.hair);
      this.px(ctx, px + 12, py + 8, 8, PIXEL_COLORS.skin);
      this.px(ctx, px + 16, py + 12, 6, PIXEL_COLORS.skin);
      this.px(ctx, px + 10, py + 16, 12, PIXEL_COLORS.armor);
      this.px(ctx, px + 4, py + 10, 4, PIXEL_COLORS.sword);
      this.px(ctx, px + 4, py + 6, 4, PIXEL_COLORS.swordDark);
      this.px(ctx, px + 10, py + 20, 12, PIXEL_COLORS.armorDark);
      this.px(ctx, px + 10, py + 24, 4, PIXEL_COLORS.pants);
      this.px(ctx, px + 18, py + 24, 4, PIXEL_COLORS.pants);
      this.px(ctx, px + 10, py + 28 + walk, 4, PIXEL_COLORS.boots);
      this.px(ctx, px + 18, py + 28 - walk, 4, PIXEL_COLORS.boots);
    }
  }
  
  drawPixelNPC(ctx, px, py, size, dir, type) {
    const colors = {
      '村长': { hair: '#cccccc', armor: '#cc8833', armorDark: '#aa6622' },
      '商人': { hair: '#884422', armor: '#44aa44', armorDark: '#338833' },
      '村民': { hair: '#aa6633', armor: '#886688', armorDark: '#664466' }
    };
    const c = colors[type] || colors['村民'];
    
    this.px(ctx, px + 8, py, 16, c.hair);
    this.px(ctx, px + 6, py + 4, 20, c.hair);
    this.px(ctx, px + 8, py + 8, 16, PIXEL_COLORS.skin);
    this.px(ctx, px + 10, py + 10, 3, '#222');
    this.px(ctx, px + 19, py + 10, 3, '#222');
    this.px(ctx, px + 8, py + 16, 16, c.armor);
    this.px(ctx, px + 6, py + 20, 20, c.armor);
    this.px(ctx, px + 8, py + 24, 6, PIXEL_COLORS.pants);
    this.px(ctx, px + 18, py + 24, 6, PIXEL_COLORS.pants);
    this.px(ctx, px + 8, py + 28, 6, PIXEL_COLORS.boots);
    this.px(ctx, px + 18, py + 28, 6, PIXEL_COLORS.boots);
  }
  
  drawPixelMonster(ctx, px, py, size, type) {
    const s = size;
    switch (type) {
      case '史莱姆':
        this.px(ctx, px + 8, py + 8, 16, PIXEL_COLORS.slime);
        this.px(ctx, px + 4, py + 12, 24, PIXEL_COLORS.slime);
        this.px(ctx, px + 2, py + 16, 28, PIXEL_COLORS.slime);
        this.px(ctx, px + 2, py + 20, 28, PIXEL_COLORS.slimeDark);
        this.px(ctx, px + 4, py + 24, 24, PIXEL_COLORS.slimeDark);
        this.px(ctx, px + 8, py + 14, 4, 2, '#fff');
        this.px(ctx, px + 20, py + 14, 4, 2, '#fff');
        this.px(ctx, px + 9, py + 15, 2, 2, '#222');
        this.px(ctx, px + 21, py + 15, 2, 2, '#222');
        break;
      case '骷髅战士':
        this.px(ctx, px + 10, py, 12, PIXEL_COLORS.skeleton);
        this.px(ctx, px + 6, py + 4, 20, PIXEL_COLORS.skeleton);
        this.px(ctx, px + 8, py + 8, 16, PIXEL_COLORS.skeleton);
        this.px(ctx, px + 10, py + 10, 4, 4, PIXEL_COLORS.skeletonEye);
        this.px(ctx, px + 18, py + 10, 4, 4, PIXEL_COLORS.skeletonEye);
        this.px(ctx, px + 14, py + 14, 4, 2, '#444');
        this.px(ctx, px + 12, py + 16, 8, PIXEL_COLORS.skeleton);
        this.px(ctx, px + 8, py + 20, 16, PIXEL_COLORS.skeleton);
        this.px(ctx, px + 4, py + 18, 4, 8, PIXEL_COLORS.skeleton);
        this.px(ctx, px + 24, py + 14, 4, 16, PIXEL_COLORS.skeletonDark);
        this.px(ctx, px + 10, py + 24, 4, 8, PIXEL_COLORS.skeleton);
        this.px(ctx, px + 18, py + 24, 4, 8, PIXEL_COLORS.skeleton);
        break;
      case '暗影法师':
        this.px(ctx, px + 8, py, 16, PIXEL_COLORS.mage);
        this.px(ctx, px + 6, py + 4, 20, PIXEL_COLORS.mage);
        this.px(ctx, px + 4, py + 8, 24, PIXEL_COLORS.mage);
        this.px(ctx, px + 10, py + 8, 4, 4, '#ffcc00');
        this.px(ctx, px + 18, py + 8, 4, 4, '#ffcc00');
        this.px(ctx, px + 12, py + 12, 8, 4, '#222');
        this.px(ctx, px + 8, py + 12, 16, PIXEL_COLORS.mage);
        this.px(ctx, px + 6, py + 16, 20, PIXEL_COLORS.mageDark);
        this.px(ctx, px + 8, py + 20, 16, PIXEL_COLORS.mageDark);
        this.px(ctx, px + 8, py + 24, 6, PIXEL_COLORS.mageSkin);
        this.px(ctx, px + 18, py + 24, 6, PIXEL_COLORS.mageSkin);
        this.px(ctx, px + 26, py + 4, 4, 28, '#886644');
        this.px(ctx, px + 24, py + 2, 8, 6, PIXEL_COLORS.mageLight);
        break;
      case '巨龙':
        this.px(ctx, px + 4, py + 4, 24, PIXEL_COLORS.dragon);
        this.px(ctx, px + 2, py + 8, 28, PIXEL_COLORS.dragon);
        this.px(ctx, px + 2, py + 12, 28, PIXEL_COLORS.dragonDark);
        this.px(ctx, px + 4, py + 16, 24, PIXEL_COLORS.dragonDark);
        this.px(ctx, px + 8, py + 10, 4, 4, '#ffff00');
        this.px(ctx, px + 20, py + 10, 4, 4, '#ffff00');
        this.px(ctx, px + 9, py + 11, 2, 2, '#ff0000');
        this.px(ctx, px + 21, py + 11, 2, 2, '#ff0000');
        this.px(ctx, px + 10, py + 16, 12, 4, PIXEL_COLORS.dragonLight);
        this.px(ctx, px + 0, py + 6, 4, 12, PIXEL_COLORS.dragonWing);
        this.px(ctx, px + 28, py + 6, 4, 12, PIXEL_COLORS.dragonWing);
        this.px(ctx, px + 6, py + 0, 4, 8, PIXEL_COLORS.dragonHorn);
        this.px(ctx, px + 22, py + 0, 4, 8, PIXEL_COLORS.dragonHorn);
        this.px(ctx, px + 10, py + 20, 6, 12, PIXEL_COLORS.dragon);
        this.px(ctx, px + 16, py + 20, 6, 12, PIXEL_COLORS.dragon);
        break;
    }
  }
  
  drawMap() {
    const ts = TILE_SIZE;
    const ctx = this.ctx;
    
    for (let y = 0; y < this.viewRows + 2; y++) {
      for (let x = 0; x < this.viewCols + 2; x++) {
        const wx = x + this.camera.x;
        const wy = y + this.camera.y;
        const sx = x * ts - (this.camera.x * ts - Math.floor(this.camera.x) * ts);
        const sy = y * ts - (this.camera.y * ts - Math.floor(this.camera.y) * ts);
        
        if (wx >= 0 && wx < MAP_COLS && wy >= 0 && wy < MAP_ROWS) {
          this.drawTile(ctx, WORLD_MAP[wy][wx], sx, sy, ts);
        } else {
          ctx.fillStyle = '#111';
          ctx.fillRect(sx, sy, ts, ts);
        }
      }
    }
  }
  
  drawNPCs() {
    const ts = TILE_SIZE;
    const ctx = this.ctx;
    
    for (const npc of this.npcs) {
      const sx = (npc.x - this.camera.x) * ts;
      const sy = (npc.y - this.camera.y) * ts;
      
      if (sx > -ts * 2 && sx < this.canvas.width / 2 + ts * 2 && sy > -ts * 2 && sy < this.canvas.height / 2 + ts * 2) {
        this.drawPixelNPC(ctx, sx + 4, sy, ts - 8, npc.dir, npc.name);
        
        ctx.fillStyle = '#fff';
        ctx.font = '10px "Press Start 2P"';
        ctx.textAlign = 'center';
        ctx.fillText(npc.name, sx + ts / 2, sy - 6);
      }
    }
  }
  
  drawPlayer() {
    const ts = TILE_SIZE;
    const ctx = this.ctx;
    const sx = (this.player.x - this.camera.x) * ts;
    const sy = (this.player.y - this.camera.y) * ts;
    
    this.drawPixelPlayer(ctx, sx + 4, sy, ts - 8, this.player.walkFrame, this.player.dir);
  }
  
  drawBattle() {
    const ctx = this.ctx;
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    
    ctx.fillStyle = '#1a0a2e';
    ctx.fillRect(0, 0, w, h);
    
    for (let i = 0; i < 30; i++) {
      const sx = (i * 37 + this.time * 0.2) % w;
      const sy = (i * 23 + Math.sin(this.time * 0.03 + i) * 10) % (h * 0.6);
      ctx.fillStyle = `rgba(255,255,255,${0.3 + Math.sin(this.time * 0.05 + i) * 0.2})`;
      ctx.fillRect(sx, sy, 2, 2);
    }
    
    ctx.fillStyle = '#0d1b2a';
    ctx.beginPath();
    ctx.moveTo(0, h);
    ctx.lineTo(0, h * 0.65);
    for (let x = 0; x <= w; x += 40) {
      ctx.lineTo(x, h * 0.6 + Math.sin(x * 0.02 + this.time * 0.01) * 15);
    }
    ctx.lineTo(w, h);
    ctx.closePath();
    ctx.fill();
    
    ctx.fillStyle = '#1b263b';
    ctx.beginPath();
    ctx.moveTo(0, h);
    ctx.lineTo(0, h * 0.75);
    for (let x = 0; x <= w; x += 30) {
      ctx.lineTo(x, h * 0.72 + Math.cos(x * 0.03 + this.time * 0.015) * 10);
    }
    ctx.lineTo(w, h);
    ctx.closePath();
    ctx.fill();
    
    const playerX = 60;
    const playerY = h - 120;
    const shake = this.battleAnim.type === 'hit' && this.time % 4 < 2 ? (this.time % 2 === 0 ? 4 : -4) : 0;
    
    this.drawPixelPlayer(ctx, playerX + shake, playerY, 32, Math.floor(this.time / 8), 3);
    
    if (this.battleAnim.type === 'playerAttack') {
      const progress = this.battleAnim.frame / this.battleAnim.maxFrame;
      const swordX = playerX + 60 + progress * 100;
      const swordY = playerY + 10;
      ctx.fillStyle = PIXEL_COLORS.swordLight;
      ctx.fillRect(swordX, swordY, 20, 4);
      ctx.fillStyle = PIXEL_COLORS.sword;
      ctx.fillRect(swordX, swordY, 20, 2);
    }
    
    if (this.currentMonster) {
      const monsterX = w - 140;
      const monsterY = h - 140;
      const mShake = this.battleAnim.type === 'hit' && this.time % 4 < 2 ? (this.time % 2 === 0 ? 6 : -6) : 0;
      const floatY = Math.sin(this.time * 0.05) * 5;
      
      this.drawPixelMonster(ctx, monsterX + mShake, monsterY + floatY, 64, this.currentMonster.name);
      
      ctx.fillStyle = '#fff';
      ctx.font = '12px "Press Start 2P"';
      ctx.textAlign = 'center';
      ctx.fillText(this.currentMonster.name, monsterX + 32, monsterY - 10 + floatY);
      
      const hpPct = this.currentMonster.hp / this.currentMonster.maxHp;
      ctx.fillStyle = 'rgba(255,255,255,0.2)';
      ctx.fillRect(monsterX, monsterY + floatY, 64, 8);
      ctx.fillStyle = '#ff006e';
      ctx.fillRect(monsterX, monsterY + floatY, 64 * hpPct, 8);
      ctx.strokeStyle = 'rgba(255,255,255,0.3)';
      ctx.lineWidth = 1;
      ctx.strokeRect(monsterX, monsterY + floatY, 64, 8);
    }
    
    if (this.battleAnim.type === 'magic') {
      const progress = this.battleAnim.frame / this.battleAnim.maxFrame;
      const mx = w - 108;
      const my = h - 108;
      for (let i = 0; i < 3; i++) {
        const radius = progress * 40 + i * 15;
        const alpha = 1 - progress;
        ctx.strokeStyle = `rgba(255, 183, 0, ${alpha})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(mx + 32, my + 32, radius, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
    
    if (this.battleAnim.type === 'heal') {
      const progress = this.battleAnim.frame / this.battleAnim.maxFrame;
      for (let i = 0; i < 5; i++) {
        const oy = progress * 40 + i * 12;
        const alpha = 1 - progress;
        ctx.fillStyle = `rgba(57, 255, 20, ${alpha})`;
        ctx.fillRect(playerX + (i - 2) * 16, playerY - oy, 4, 4);
      }
    }
    
    if (this.battleAnim.type === 'levelUp') {
      const progress = this.battleAnim.frame / this.battleAnim.maxFrame;
      const alpha = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
      ctx.fillStyle = `rgba(255, 183, 0, ${alpha * 0.2})`;
      ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = `rgba(255, 183, 0, ${alpha})`;
      ctx.font = 'bold 20px "Press Start 2P"';
      ctx.textAlign = 'center';
      ctx.fillText('LEVEL UP!', w / 2, h / 2);
    }
    
    if (this.battleVictory) {
      const alpha = Math.min(1, this.time * 0.02);
      ctx.fillStyle = `rgba(0,0,0,${alpha * 0.7})`;
      ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = PIXEL_COLORS.chestLight;
      ctx.font = '16px "Press Start 2P"';
      ctx.textAlign = 'center';
      ctx.fillText('VICTORY!', w / 2, h / 2);
    }
  }
  
  drawDialogue() {
    if (!this.showingDialogue || this.currentDialogue.length === 0) return;
    
    const ctx = this.ctx;
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    const boxH = 80;
    const boxY = h - boxH - 20;
    
    ctx.fillStyle = 'rgba(10,10,30,0.9)';
    ctx.strokeStyle = '#00d4ff';
    ctx.lineWidth = 2;
    ctx.fillRect(20, boxY, w - 40, boxH);
    ctx.strokeRect(20, boxY, w - 40, boxH);
    
    ctx.fillStyle = '#fff';
    ctx.font = '12px "Noto Sans SC"';
    ctx.textAlign = 'left';
    ctx.fillText(this.currentDialogue[this.dialogueIndex] || '', 40, boxY + 35);
    
    ctx.fillStyle = '#00d4ff';
    ctx.font = '10px "Press Start 2P"';
    ctx.textAlign = 'right';
    const blink = Math.sin(this.time * 0.1) > 0;
    if (blink) ctx.fillText('按空格继续', w - 40, boxY + 60);
  }
  
  drawSign() {
    if (!this.showingSign) return;
    
    const ctx = this.ctx;
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    const boxH = 60;
    const boxY = h - boxH - 20;
    
    ctx.fillStyle = 'rgba(10,10,30,0.9)';
    ctx.strokeStyle = '#ffb700';
    ctx.lineWidth = 2;
    ctx.fillRect(20, boxY, w - 40, boxH);
    ctx.strokeRect(20, boxY, w - 40, boxH);
    
    ctx.fillStyle = '#ffb700';
    ctx.font = '12px "Noto Sans SC"';
    ctx.textAlign = 'left';
    ctx.fillText(this.signText, 40, boxY + 35);
  }
  
  drawHUD() {
    const ctx = this.ctx;
    const w = this.canvas.width / 2;
    
    ctx.fillStyle = 'rgba(10,10,30,0.8)';
    ctx.fillRect(10, 10, 180, 70);
    ctx.strokeStyle = 'rgba(0,212,255,0.3)';
    ctx.lineWidth = 1;
    ctx.strokeRect(10, 10, 180, 70);
    
    ctx.fillStyle = '#fff';
    ctx.font = '10px "Press Start 2P"';
    ctx.textAlign = 'left';
    ctx.fillText(`Lv.${this.player.level}`, 20, 28);
    ctx.fillStyle = '#ff006e';
    ctx.fillText(`HP ${this.player.hp}/${this.player.maxHp}`, 20, 44);
    ctx.fillStyle = '#00d4ff';
    ctx.fillText(`MP ${this.player.mp}/${this.player.maxMp}`, 20, 60);
    ctx.fillStyle = '#ffb700';
    ctx.fillText(`G ${this.player.gold}`, 120, 28);
  }
  
  drawTitle() {
    if (!this.gameStarted) return;
    
    const ctx = this.ctx;
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(0, 0, w, 40);
    
    ctx.fillStyle = '#ffb700';
    ctx.font = '14px "Press Start 2P"';
    ctx.textAlign = 'center';
    ctx.fillText('勇者斗恶龙', w / 2, 28);
    
    ctx.fillStyle = '#666';
    ctx.font = '8px "Press Start 2P"';
    ctx.fillText('方向键/WASD移动 空格交互', w / 2, h - 10);
  }
  
  render() {
    const ctx = this.ctx;
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    
    ctx.clearRect(0, 0, w, h);
    
    if (!this.gameStarted) return;
    
    if (this.isBattling) {
      if (this.battleAnim.frame < this.battleAnim.maxFrame) {
        this.battleAnim.frame++;
      }
      this.drawBattle();
    } else {
      this.drawMap();
      this.drawNPCs();
      this.drawPlayer();
      this.drawHUD();
      this.drawTitle();
      this.drawDialogue();
      this.drawSign();
    }
  }
  
  startRenderLoop() {
    const loop = () => {
      this.update();
      this.render();
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }
}
