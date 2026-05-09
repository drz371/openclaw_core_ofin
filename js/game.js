class DQGame {
  constructor() {
    this.canvas = document.getElementById('gameCanvas');
    this.ctx = this.canvas.getContext('2d');
    this.overlay = document.getElementById('gameOverlay');
    this.overlayTitle = document.getElementById('overlayTitle');
    this.overlayMessage = document.getElementById('overlayMessage');
    this.startBtn = document.getElementById('startGameBtn');
    this.logContent = document.getElementById('logContent');
    
    this.player = {
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
      isDefending: false
    };
    
    this.monsters = [
      { name: '史莱姆', hp: 30, maxHp: 30, atk: 5, exp: 10, skill: '分裂', color: '#39ff14', difficulty: 1 },
      { name: '骷髅战士', hp: 60, maxHp: 60, atk: 12, exp: 25, skill: '骨刃', color: '#b8b8d0', difficulty: 2 },
      { name: '暗影法师', hp: 45, maxHp: 45, atk: 18, exp: 35, skill: '暗影箭', color: '#7b2ff7', difficulty: 3 },
      { name: '巨龙', hp: 150, maxHp: 150, atk: 25, exp: 100, skill: '龙息', color: '#ff006e', difficulty: 4 }
    ];
    
    this.currentMonsterIndex = 0;
    this.currentMonster = null;
    this.isBattling = false;
    this.isPlayerTurn = true;
    this.animationFrame = 0;
    this.battleAnimations = {
      playerAttack: { active: false, frame: 0, maxFrame: 15 },
      monsterAttack: { active: false, frame: 0, maxFrame: 15 },
      magicEffect: { active: false, frame: 0, maxFrame: 20 },
      healEffect: { active: false, frame: 0, maxFrame: 15 },
      damageShake: { active: false, frame: 0, maxFrame: 10 },
      levelUp: { active: false, frame: 0, maxFrame: 30 }
    };
    this.particles = [];
    this.stars = [];
    this.sceneTransition = { active: false, alpha: 0, direction: 1 };
    
    this.initCanvas();
    this.bindEvents();
    this.generateStars();
    this.startRenderLoop();
  }
  
  initCanvas() {
    const wrapper = this.canvas.parentElement;
    this.canvas.width = wrapper.offsetWidth * 2;
    this.canvas.height = wrapper.offsetHeight * 2;
    this.ctx.scale(2, 2);
  }
  
  bindEvents() {
    this.startBtn.addEventListener('click', () => this.startGame());
    
    const actionBtns = document.querySelectorAll('.action-btn');
    actionBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        if (!this.isBattling || !this.isPlayerTurn) return;
        this.playerAction(btn.dataset.action);
      });
    });
  }
  
  generateStars() {
    for (let i = 0; i < 50; i++) {
      this.stars.push({
        x: Math.random() * this.canvas.width / 2,
        y: Math.random() * this.canvas.height / 2 * 0.6,
        size: Math.random() * 2 + 0.5,
        twinkle: Math.random() * Math.PI * 2,
        speed: Math.random() * 0.02 + 0.01
      });
    }
  }
  
  startGame() {
    this.currentMonsterIndex = 0;
    this.player = {
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
      isDefending: false
    };
    this.overlay.classList.add('hidden');
    this.logContent.innerHTML = '';
    this.updatePlayerUI();
    this.startBattle();
  }
  
  startBattle() {
    if (this.currentMonsterIndex >= this.monsters.length) {
      this.showOverlay('冒险完成!', '你已成功击败所有怪物!');
      this.isBattling = false;
      return;
    }
    
    this.currentMonster = { ...this.monsters[this.currentMonsterIndex] };
    this.isBattling = true;
    this.isPlayerTurn = true;
    this.player.isDefending = false;
    this.updateMonsterUI();
    this.updatePlayerUI();
    this.enableActionButtons(true);
    
    this.addLog(`${this.currentMonster.name} 出现了!`, 'system');
  }
  
  playerAction(action) {
    if (!this.isPlayerTurn || !this.isBattling) return;
    
    this.isPlayerTurn = false;
    this.player.isDefending = false;
    this.enableActionButtons(false);
    
    switch (action) {
      case 'attack':
        this.battleAnimations.playerAttack = { active: true, frame: 0, maxFrame: 15 };
        setTimeout(() => {
          const damage = Math.max(1, this.player.atk + Math.floor(Math.random() * 6) - 3);
          this.currentMonster.hp = Math.max(0, this.currentMonster.hp - damage);
          this.addLog(`你造成了 ${damage} 点伤害!`, 'player');
          this.battleAnimations.damageShake = { active: true, frame: 0, maxFrame: 10 };
          this.createHitParticles();
          this.updateMonsterUI();
          this.checkMonsterStatus();
        }, 300);
        break;
        
      case 'magic':
        if (this.player.mp < 5) {
          this.addLog('MP不足!', 'system');
          this.isPlayerTurn = true;
          this.enableActionButtons(true);
          return;
        }
        this.player.mp -= 5;
        this.battleAnimations.magicEffect = { active: true, frame: 0, maxFrame: 20 };
        setTimeout(() => {
          const damage = Math.max(1, this.player.atk * 2 + Math.floor(Math.random() * 10) - 5);
          this.currentMonster.hp = Math.max(0, this.currentMonster.hp - damage);
          this.addLog(`火焰魔法造成了 ${damage} 点伤害!`, 'player');
          this.battleAnimations.damageShake = { active: true, frame: 0, maxFrame: 10 };
          this.createHitParticles();
          this.updateMonsterUI();
          this.updatePlayerUI();
          this.checkMonsterStatus();
        }, 500);
        break;
        
      case 'heal':
        if (this.player.mp < 8) {
          this.addLog('MP不足!', 'system');
          this.isPlayerTurn = true;
          this.enableActionButtons(true);
          return;
        }
        this.player.mp -= 8;
        this.battleAnimations.healEffect = { active: true, frame: 0, maxFrame: 15 };
        setTimeout(() => {
          const heal = 25 + Math.floor(Math.random() * 10);
          this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal);
          this.addLog(`治疗恢复了 ${heal} 点HP!`, 'heal');
          this.updatePlayerUI();
          this.enemyTurn();
        }, 500);
        return;
        
      case 'defend':
        this.player.isDefending = true;
        this.addLog('你举起盾牌进行防御!', 'player');
        this.enemyTurn();
        return;
        
      case 'item':
        if (this.player.potions <= 0) {
          this.addLog('没有药水了!', 'system');
          this.isPlayerTurn = true;
          this.enableActionButtons(true);
          return;
        }
        this.player.potions--;
        this.battleAnimations.healEffect = { active: true, frame: 0, maxFrame: 15 };
        setTimeout(() => {
          const heal = 40;
          this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal);
          this.addLog(`使用药水恢复了 ${heal} 点HP!`, 'heal');
          this.updatePlayerUI();
          this.enemyTurn();
        }, 500);
        return;
    }
    
    if (action === 'attack' || action === 'magic') {
      setTimeout(() => {
        if (this.currentMonster.hp > 0) {
          this.enemyTurn();
        }
      }, 800);
    }
  }
  
  enemyTurn() {
    setTimeout(() => {
      this.battleAnimations.monsterAttack = { active: true, frame: 0, maxFrame: 15 };
      
      setTimeout(() => {
        let baseDamage = this.currentMonster.atk + Math.floor(Math.random() * 6) - 3;
        const useSkill = Math.random() < 0.3;
        
        if (useSkill) {
          baseDamage = Math.floor(baseDamage * 1.5);
          this.addLog(`${this.currentMonster.name} 使用了 ${this.currentMonster.skill}!`, 'enemy');
        }
        
        if (this.player.isDefending) {
          baseDamage = Math.floor(baseDamage * 0.5);
        }
        
        const damage = Math.max(1, baseDamage - Math.floor(this.player.def * 0.5));
        this.player.hp = Math.max(0, this.player.hp - damage);
        
        this.addLog(`受到了 ${damage} 点伤害!`, 'enemy');
        this.battleAnimations.damageShake = { active: true, frame: 0, maxFrame: 10 };
        this.createHitParticles(true);
        this.updatePlayerUI();
        
        if (this.player.hp <= 0) {
          this.addLog('你被击败了...', 'system');
          this.isBattling = false;
          this.showOverlay('战败', '你被怪物击败了...');
          return;
        }
        
        this.isPlayerTurn = true;
        this.enableActionButtons(true);
      }, 400);
    }, 500);
  }
  
  checkMonsterStatus() {
    if (this.currentMonster.hp <= 0) {
      this.addLog(`${this.currentMonster.name} 被击败了!`, 'system');
      this.player.exp += this.currentMonster.exp;
      this.addLog(`获得了 ${this.currentMonster.exp} 点经验值!`, 'system');
      
      if (this.player.exp >= this.player.expToLevel) {
        this.levelUp();
      }
      
      this.currentMonsterIndex++;
      this.updatePlayerUI();
      
      setTimeout(() => {
        this.startBattle();
      }, 1500);
    }
  }
  
  levelUp() {
    this.player.level++;
    this.player.exp -= this.player.expToLevel;
    this.player.expToLevel = Math.floor(this.player.expToLevel * 1.5);
    
    this.player.maxHp += 15;
    this.player.hp = this.player.maxHp;
    this.player.maxMp += 8;
    this.player.mp = this.player.maxMp;
    this.player.atk += 4;
    this.player.def += 3;
    
    this.addLog(`升级! 你现在是 Lv.${this.player.level}!`, 'system');
    this.battleAnimations.levelUp = { active: true, frame: 0, maxFrame: 30 };
  }
  
  showOverlay(title, message) {
    this.overlayTitle.textContent = title;
    this.overlayMessage.textContent = message;
    this.startBtn.textContent = '重新开始';
    this.overlay.classList.remove('hidden');
  }
  
  addLog(message, type) {
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    entry.textContent = message;
    this.logContent.appendChild(entry);
    this.logContent.scrollTop = this.logContent.scrollHeight;
  }
  
  updatePlayerUI() {
    document.getElementById('playerLevel').textContent = `Lv.${this.player.level}`;
    document.getElementById('playerHp').textContent = `${this.player.hp}/${this.player.maxHp}`;
    document.getElementById('playerHpBar').style.width = `${(this.player.hp / this.player.maxHp) * 100}%`;
    document.getElementById('playerMp').textContent = `${this.player.mp}/${this.player.maxMp}`;
    document.getElementById('playerMpBar').style.width = `${(this.player.mp / this.player.maxMp) * 100}%`;
    document.getElementById('playerExp').textContent = `${this.player.exp}/${this.player.expToLevel}`;
    document.getElementById('playerExpBar').style.width = `${(this.player.exp / this.player.expToLevel) * 100}%`;
    document.getElementById('playerAtk').textContent = this.player.atk;
    document.getElementById('playerDef').textContent = this.player.def;
    document.getElementById('potionCount').textContent = this.player.potions;
  }
  
  updateMonsterUI() {
  }
  
  enableActionButtons(enabled) {
    const btns = document.querySelectorAll('.action-btn');
    btns.forEach(btn => btn.disabled = !enabled);
  }
  
  createHitParticles(isPlayer = false) {
    const x = isPlayer ? 150 : this.canvas.width / 2 / 2 - 50;
    const y = isPlayer ? this.canvas.height / 2 / 2 + 20 : this.canvas.height / 2 / 2 - 30;
    
    for (let i = 0; i < 8; i++) {
      this.particles.push({
        x: x,
        y: y,
        vx: (Math.random() - 0.5) * 4,
        vy: (Math.random() - 0.5) * 4,
        life: 30,
        maxLife: 30,
        size: Math.random() * 3 + 2,
        color: isPlayer ? '#ff006e' : '#ffb700'
      });
    }
  }
  
  updateParticles() {
    this.particles = this.particles.filter(p => {
      p.x += p.vx;
      p.y += p.vy;
      p.life--;
      return p.life > 0;
    });
  }
  
  renderParticles() {
    this.particles.forEach(p => {
      const alpha = p.life / p.maxLife;
      this.ctx.fillStyle = p.color;
      this.ctx.globalAlpha = alpha;
      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      this.ctx.fill();
    });
    this.ctx.globalAlpha = 1;
  }
  
  drawBackground() {
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    
    const gradient = this.ctx.createLinearGradient(0, 0, 0, h);
    gradient.addColorStop(0, '#0a0a1a');
    gradient.addColorStop(0.4, '#1a0a2e');
    gradient.addColorStop(1, '#0f3460');
    this.ctx.fillStyle = gradient;
    this.ctx.fillRect(0, 0, w, h);
    
    this.stars.forEach(star => {
      star.twinkle += star.speed;
      const alpha = 0.3 + Math.sin(star.twinkle) * 0.3;
      this.ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
      this.ctx.beginPath();
      this.ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
      this.ctx.fill();
    });
    
    this.ctx.fillStyle = '#0d1b2a';
    this.ctx.beginPath();
    this.ctx.moveTo(0, h);
    this.ctx.lineTo(0, h * 0.7);
    this.ctx.quadraticCurveTo(w * 0.25, h * 0.6, w * 0.5, h * 0.65);
    this.ctx.quadraticCurveTo(w * 0.75, h * 0.7, w, h * 0.6);
    this.ctx.lineTo(w, h);
    this.ctx.closePath();
    this.ctx.fill();
    
    this.ctx.fillStyle = '#1b263b';
    this.ctx.beginPath();
    this.ctx.moveTo(0, h);
    this.ctx.lineTo(0, h * 0.8);
    this.ctx.quadraticCurveTo(w * 0.3, h * 0.75, w * 0.5, h * 0.78);
    this.ctx.quadraticCurveTo(w * 0.7, h * 0.8, w, h * 0.75);
    this.ctx.lineTo(w, h);
    this.ctx.closePath();
    this.ctx.fill();
  }
  
  drawPlayer() {
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    const shake = this.battleAnimations.damageShake.active ? 
      Math.sin(this.battleAnimations.damageShake.frame * 2) * 3 : 0;
    
    const x = 100 + shake;
    const y = h - 100;
    
    const attackOffset = this.battleAnimations.playerAttack.active ? 
      Math.sin(this.battleAnimations.playerAttack.frame / 15 * Math.PI) * 30 : 0;
    
    const glowPulse = Math.sin(this.animationFrame * 0.05) * 0.3 + 0.7;
    
    this.ctx.save();
    this.ctx.shadowColor = 'rgba(0, 212, 255, 0.5)';
    this.ctx.shadowBlur = 20 * glowPulse;
    
    this.ctx.fillStyle = '#00d4ff';
    this.ctx.beginPath();
    this.ctx.ellipse(x + attackOffset, y - 30, 15, 20, 0, 0, Math.PI * 2);
    this.ctx.fill();
    
    this.ctx.fillStyle = '#1a0a2e';
    this.ctx.beginPath();
    this.ctx.moveTo(x - 10 + attackOffset, y - 50);
    this.ctx.lineTo(x + attackOffset, y - 70);
    this.ctx.lineTo(x + 10 + attackOffset, y - 50);
    this.ctx.closePath();
    this.ctx.fill();
    
    this.ctx.fillStyle = '#7b2ff7';
    this.ctx.fillRect(x - 8 + attackOffset, y - 10, 16, 25);
    
    this.ctx.fillStyle = '#ffb700';
    this.ctx.fillRect(x - 6 + attackOffset, y, 5, 15);
    this.ctx.fillRect(x + 1 + attackOffset, y, 5, 15);
    
    this.ctx.strokeStyle = '#00d4ff';
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    this.ctx.moveTo(x + 15 + attackOffset, y - 20);
    this.ctx.lineTo(x + 35 + attackOffset, y - 40);
    this.ctx.stroke();
    
    this.ctx.fillStyle = '#ff006e';
    this.ctx.beginPath();
    this.ctx.moveTo(x + 30 + attackOffset, y - 50);
    this.ctx.lineTo(x + 35 + attackOffset, y - 55);
    this.ctx.lineTo(x + 40 + attackOffset, y - 45);
    this.ctx.closePath();
    this.ctx.fill();
    
    this.ctx.restore();
  }
  
  drawMonster() {
    if (!this.currentMonster) return;
    
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    const shake = this.battleAnimations.damageShake.active ? 
      Math.sin(this.battleAnimations.damageShake.frame * 2) * 4 : 0;
    
    const monsterAttackOffset = this.battleAnimations.monsterAttack.active ? 
      Math.sin(this.battleAnimations.monsterAttack.frame / 15 * Math.PI) * -30 : 0;
    
    const x = w - 120 + shake + monsterAttackOffset;
    const y = h - 100;
    
    const floatOffset = Math.sin(this.animationFrame * 0.03) * 8;
    const glowPulse = Math.sin(this.animationFrame * 0.05) * 0.3 + 0.7;
    
    this.ctx.save();
    this.ctx.shadowColor = this.currentMonster.color;
    this.ctx.shadowBlur = 25 * glowPulse;
    
    this.ctx.fillStyle = this.currentMonster.color;
    
    switch (this.currentMonster.difficulty) {
      case 1:
        this.ctx.beginPath();
        this.ctx.ellipse(x, y + floatOffset - 20, 25, 20, 0, 0, Math.PI * 2);
        this.ctx.fill();
        this.ctx.beginPath();
        this.ctx.ellipse(x, y + floatOffset, 20, 15, 0, 0, Math.PI);
        this.ctx.fill();
        
        this.ctx.fillStyle = '#000';
        this.ctx.beginPath();
        this.ctx.arc(x - 8, y + floatOffset - 25, 3, 0, Math.PI * 2);
        this.ctx.arc(x + 8, y + floatOffset - 25, 3, 0, Math.PI * 2);
        this.ctx.fill();
        
        this.ctx.fillStyle = '#00d4ff';
        this.ctx.beginPath();
        this.ctx.arc(x - 8, y + floatOffset - 26, 1, 0, Math.PI * 2);
        this.ctx.arc(x + 8, y + floatOffset - 26, 1, 0, Math.PI * 2);
        this.ctx.fill();
        break;
        
      case 2:
        this.ctx.fillRect(x - 20, y + floatOffset - 50, 40, 60);
        this.ctx.fillStyle = '#2a2a4a';
        this.ctx.fillRect(x - 15, y + floatOffset - 45, 10, 10);
        this.ctx.fillRect(x + 5, y + floatOffset - 45, 10, 10);
        this.ctx.fillStyle = '#ff006e';
        this.ctx.beginPath();
        this.ctx.arc(x - 10, y + floatOffset - 40, 3, 0, Math.PI * 2);
        this.ctx.arc(x + 10, y + floatOffset - 40, 3, 0, Math.PI * 2);
        this.ctx.fill();
        this.ctx.fillStyle = this.currentMonster.color;
        this.ctx.fillRect(x - 5, y + floatOffset, 10, 30);
        break;
        
      case 3:
        this.ctx.beginPath();
        this.ctx.moveTo(x, y + floatOffset - 60);
        this.ctx.lineTo(x - 25, y + floatOffset - 20);
        this.ctx.lineTo(x - 20, y + floatOffset + 20);
        this.ctx.lineTo(x + 20, y + floatOffset + 20);
        this.ctx.lineTo(x + 25, y + floatOffset - 20);
        this.ctx.closePath();
        this.ctx.fill();
        
        this.ctx.fillStyle = '#ff006e';
        this.ctx.beginPath();
        this.ctx.arc(x - 8, y + floatOffset - 30, 4, 0, Math.PI * 2);
        this.ctx.arc(x + 8, y + floatOffset - 30, 4, 0, Math.PI * 2);
        this.ctx.fill();
        
        this.ctx.strokeStyle = this.currentMonster.color;
        this.ctx.lineWidth = 2;
        this.ctx.beginPath();
        this.ctx.moveTo(x - 25, y + floatOffset - 10);
        this.ctx.lineTo(x - 45, y + floatOffset - 30);
        this.ctx.moveTo(x + 25, y + floatOffset - 10);
        this.ctx.lineTo(x + 45, y + floatOffset - 30);
        this.ctx.stroke();
        break;
        
      case 4:
        this.ctx.beginPath();
        this.ctx.ellipse(x, y + floatOffset - 30, 40, 50, 0, 0, Math.PI * 2);
        this.ctx.fill();
        
        this.ctx.fillStyle = '#ffb700';
        this.ctx.beginPath();
        this.ctx.moveTo(x - 20, y + floatOffset - 70);
        this.ctx.lineTo(x - 30, y + floatOffset - 100);
        this.ctx.lineTo(x - 5, y + floatOffset - 75);
        this.ctx.closePath();
        this.ctx.fill();
        this.ctx.beginPath();
        this.ctx.moveTo(x + 20, y + floatOffset - 70);
        this.ctx.lineTo(x + 30, y + floatOffset - 100);
        this.ctx.lineTo(x + 5, y + floatOffset - 75);
        this.ctx.closePath();
        this.ctx.fill();
        
        this.ctx.fillStyle = '#00d4ff';
        this.ctx.beginPath();
        this.ctx.arc(x - 12, y + floatOffset - 40, 6, 0, Math.PI * 2);
        this.ctx.arc(x + 12, y + floatOffset - 40, 6, 0, Math.PI * 2);
        this.ctx.fill();
        
        this.ctx.fillStyle = '#ff0000';
        this.ctx.beginPath();
        this.ctx.arc(x - 12, y + floatOffset - 40, 3, 0, Math.PI * 2);
        this.ctx.arc(x + 12, y + floatOffset - 40, 3, 0, Math.PI * 2);
        this.ctx.fill();
        
        this.ctx.fillStyle = '#1a0a2e';
        this.ctx.beginPath();
        this.ctx.moveTo(x - 15, y + floatOffset - 15);
        this.ctx.quadraticCurveTo(x, y + floatOffset - 5, x + 15, y + floatOffset - 15);
        this.ctx.closePath();
        this.ctx.fill();
        break;
    }
    
    this.ctx.restore();
    
    this.ctx.fillStyle = '#ffffff';
    this.ctx.font = '14px "Noto Sans SC"';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(this.currentMonster.name, x, y + floatOffset + 45);
    
    const hpPercent = this.currentMonster.hp / this.currentMonster.maxHp;
    const barWidth = 80;
    const barX = x - barWidth / 2;
    const barY = y + floatOffset + 55;
    
    this.ctx.fillStyle = 'rgba(255,255,255,0.2)';
    this.ctx.fillRect(barX, barY, barWidth, 8);
    
    const hpGradient = this.ctx.createLinearGradient(barX, 0, barX + barWidth, 0);
    hpGradient.addColorStop(0, '#ff006e');
    hpGradient.addColorStop(1, '#ff4d6d');
    this.ctx.fillStyle = hpGradient;
    this.ctx.fillRect(barX, barY, barWidth * hpPercent, 8);
    
    this.ctx.strokeStyle = 'rgba(255,255,255,0.3)';
    this.ctx.lineWidth = 1;
    this.ctx.strokeRect(barX, barY, barWidth, 8);
  }
  
  drawMagicEffect() {
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    const x = w - 120;
    const y = h - 120;
    const progress = this.battleAnimations.magicEffect.frame / 20;
    
    this.ctx.save();
    for (let i = 0; i < 3; i++) {
      const radius = progress * 60 + i * 20;
      const alpha = 1 - progress;
      this.ctx.strokeStyle = `rgba(255, 183, 0, ${alpha})`;
      this.ctx.lineWidth = 3;
      this.ctx.beginPath();
      this.ctx.arc(x, y, radius, 0, Math.PI * 2);
      this.ctx.stroke();
    }
    this.ctx.restore();
  }
  
  drawHealEffect() {
    const x = 100;
    const y = this.canvas.height / 2 / 2 - 20;
    const progress = this.battleAnimations.healEffect.frame / 15;
    
    this.ctx.save();
    for (let i = 0; i < 5; i++) {
      const offsetY = progress * 50 + i * 15;
      const alpha = 1 - progress;
      this.ctx.fillStyle = `rgba(57, 255, 20, ${alpha})`;
      this.ctx.beginPath();
      this.ctx.arc(x + (i - 2) * 20, y - offsetY, 4, 0, Math.PI * 2);
      this.ctx.fill();
    }
    this.ctx.restore();
  }
  
  drawLevelUp() {
    const w = this.canvas.width / 2;
    const h = this.canvas.height / 2;
    const progress = this.battleAnimations.levelUp.frame / 30;
    const alpha = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
    
    this.ctx.save();
    this.ctx.fillStyle = `rgba(255, 183, 0, ${alpha * 0.3})`;
    this.ctx.fillRect(0, 0, w, h);
    
    this.ctx.fillStyle = `rgba(255, 183, 0, ${alpha})`;
    this.ctx.font = 'bold 24px "Press Start 2P"';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('LEVEL UP!', w / 2, h / 2);
    this.ctx.restore();
  }
  
  updateAnimations() {
    Object.keys(this.battleAnimations).forEach(key => {
      if (this.battleAnimations[key].active) {
        this.battleAnimations[key].frame++;
        if (this.battleAnimations[key].frame >= this.battleAnimations[key].maxFrame) {
          this.battleAnimations[key].active = false;
        }
      }
    });
  }
  
  render() {
    this.ctx.clearRect(0, 0, this.canvas.width / 2, this.canvas.height / 2);
    
    this.drawBackground();
    
    if (this.isBattling && this.currentMonster) {
      this.drawPlayer();
      this.drawMonster();
      
      if (this.battleAnimations.magicEffect.active) this.drawMagicEffect();
      if (this.battleAnimations.healEffect.active) this.drawHealEffect();
      if (this.battleAnimations.levelUp.active) this.drawLevelUp();
    }
    
    this.renderParticles();
  }
  
  startRenderLoop() {
    const loop = () => {
      this.animationFrame++;
      this.updateAnimations();
      this.updateParticles();
      this.render();
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }
}
