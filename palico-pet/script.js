// 艾露猫桌面宠物 - 交互脚本

class PalicoPet {
    constructor() {
        // 状态值
        this.state = {
            hunger: 80,      // 饥饿度 0-100
            happiness: 80,   // 心情 0-100
            energy: 80,      // 精力 0-100
            isSleeping: false,
            isDragging: false,
            currentAction: null
        };

        // 对话内容
        this.dialogues = {
            greeting: [
                '喵~ 欢迎来到这里！🐱',
                '艾露猫来陪你啦！喵！',
                '今天也要加油哦！喵呜~',
                '喵~ 有什么需要我帮忙的吗？'
            ],
            feed: [
                '好好吃！喵呜~ 🐟',
                '谢谢你！最喜欢烤肉了！',
                '喵~ 肚子饱饱的！',
                ' yummy！再来一条鱼吧！🐟'
            ],
            play: [
                '好开心！喵！🎵',
                '再来再来！喵呜~',
                '艾露猫最擅长玩了！',
                '喵~ 好快乐！🎾'
            ],
            rest: [
                '有点困了...喵💤',
                '让艾露猫休息一下...zzz',
                '喵~ 好舒服的觉...',
                '呼噜呼噜...💤'
            ],
            pet: [
                '好舒服~ 喵呜~ ❤️',
                '再摸摸！喵！',
                '最喜欢被抚摸啦！',
                '呼噜呼噜...开心！😻'
            ],
            hungry: [
                '肚子饿了...喵🍖',
                '想吃烤肉...',
                '喵呜~ 给点吃的吧...'
            ],
            sad: [
                '有点无聊...喵',
                '陪我玩嘛~',
                '喵...心情不太好...'
            ],
            tired: [
                '好困啊...喵💤',
                '让我睡一会儿...',
                '喵...没力气了...'
            ],
            random: [
                '喵~ 今天天气真好！',
                '艾露猫最棒了！喵！',
                '要不要一起去打猎？🏹',
                '喵~ 你最喜欢什么怪物？',
                '我梦到好多鱼...喵😋',
                '喵呜~ 你是个好猎人！',
                '我们一起变强吧！💪'
            ]
        };

        this.init();
    }

    init() {
        // 缓存DOM元素
        this.palico = document.getElementById('palico');
        this.speechBubble = document.getElementById('speech-bubble');
        this.bubbleText = document.getElementById('bubble-text');
        this.leftEye = document.getElementById('eye-left');
        this.rightEye = document.getElementById('eye-right');
        this.mouth = document.getElementById('mouth');

        // 绑定事件
        this.bindEvents();

        // 初始化状态条
        this.updateStatusBars();

        // 开始随机动作
        this.startRandomActions();

        // 状态衰减
        this.startStateDecay();

        // 显示初始问候
        setTimeout(() => this.showRandomDialogue('greeting'), 1000);

        // 定期眨眼
        this.startBlinking();
    }

    bindEvents() {
        // 拖拽功能
        let isDragging = false;
        let startX, startY, startLeft, startTop;

        this.palico.addEventListener('mousedown', (e) => {
            isDragging = true;
            this.state.isDragging = true;
            this.palico.classList.add('dragging');

            startX = e.clientX;
            startY = e.clientY;

            const rect = this.palico.getBoundingClientRect();
            startLeft = rect.left;
            startTop = rect.top;
        });

        document.addEventListener('mousemove', (e) => {
            if (!isDragging) return;

            const dx = e.clientX - startX;
            const dy = e.clientY - startY;

            this.palico.style.position = 'fixed';
            this.palico.style.left = (startLeft + dx) + 'px';
            this.palico.style.top = (startTop + dy) + 'px';
            this.palico.style.bottom = 'auto';
            this.palico.style.transform = 'none';
        });

        document.addEventListener('mouseup', () => {
            if (isDragging) {
                isDragging = false;
                this.state.isDragging = false;
                this.palico.classList.remove('dragging');
            }
        });

        // 按钮事件
        document.getElementById('btn-feed').addEventListener('click', () => this.feed());
        document.getElementById('btn-play').addEventListener('click', () => this.play());
        document.getElementById('btn-rest').addEventListener('click', () => this.rest());
        document.getElementById('btn-pet').addEventListener('click', () => this.pet());

        // 触摸支持
        let touchStartX, touchStartY, touchStartLeft, touchStartTop;

        this.palico.addEventListener('touchstart', (e) => {
            isDragging = true;
            this.state.isDragging = true;
            this.palico.classList.add('dragging');

            const touch = e.touches[0];
            touchStartX = touch.clientX;
            touchStartY = touch.clientY;

            const rect = this.palico.getBoundingClientRect();
            touchStartLeft = rect.left;
            touchStartTop = rect.top;
        });

        document.addEventListener('touchmove', (e) => {
            if (!isDragging) return;

            const touch = e.touches[0];
            const dx = touch.clientX - touchStartX;
            const dy = touch.clientY - touchStartY;

            this.palico.style.position = 'fixed';
            this.palico.style.left = (touchStartLeft + dx) + 'px';
            this.palico.style.top = (touchStartTop + dy) + 'px';
            this.palico.style.bottom = 'auto';
            this.palico.style.transform = 'none';
        });

        document.addEventListener('touchend', () => {
            if (isDragging) {
                isDragging = false;
                this.state.isDragging = false;
                this.palico.classList.remove('dragging');
            }
        });
    }

    // 更新状态条
    updateStatusBars() {
        const hungerFill = document.getElementById('hunger-fill');
        const happinessFill = document.getElementById('happiness-fill');
        const energyFill = document.getElementById('energy-fill');

        hungerFill.style.setProperty('--fill-percent', this.state.hunger + '%');
        happinessFill.style.setProperty('--fill-percent', this.state.happiness + '%');
        energyFill.style.setProperty('--fill-percent', this.state.energy + '%');

        // 根据数值改变颜色
        this.updateBarColor(hungerFill, this.state.hunger);
        this.updateBarColor(happinessFill, this.state.happiness);
        this.updateBarColor(energyFill, this.state.energy);
    }

    updateBarColor(element, value) {
        let color;
        if (value > 60) {
            color = '#4CAF50';
        } else if (value > 30) {
            color = '#FF9800';
        } else {
            color = '#F44336';
        }
        element.style.setProperty('--fill-color', color);
    }

    // 显示对话
    showDialogue(text) {
        this.bubbleText.textContent = text;
        this.speechBubble.classList.add('show');

        setTimeout(() => {
            this.speechBubble.classList.remove('show');
        }, 3000);
    }

    // 随机对话
    showRandomDialogue(category) {
        const dialogues = this.dialogues[category];
        const text = dialogues[Math.floor(Math.random() * dialogues.length)];
        this.showDialogue(text);
    }

    // 创建特效
    createEffect(type, x, y) {
        const effect = document.createElement('div');
        effect.className = type;
        effect.textContent = type === 'heart' ? '❤️' : type === 'zzz' ? '💤' : '🎵';
        effect.style.left = x + 'px';
        effect.style.top = y + 'px';

        document.body.appendChild(effect);

        setTimeout(() => effect.remove(), type === 'zzz' ? 2000 : 1000);
    }

    // 眨眼
    startBlinking() {
        setInterval(() => {
            if (this.state.isSleeping) return;

            this.leftEye.classList.add('blink');
            this.rightEye.classList.add('blink');

            setTimeout(() => {
                this.leftEye.classList.remove('blink');
                this.rightEye.classList.remove('blink');
            }, 150);
        }, 4000);
    }

    // 随机动作
    startRandomActions() {
        setInterval(() => {
            if (this.state.isSleeping || this.state.isDragging) return;

            const rand = Math.random();

            if (rand < 0.2) {
                // 摇尾巴加速
                this.palico.style.setProperty('--tail-speed', '0.5s');
                setTimeout(() => {
                    this.palico.style.setProperty('--tail-speed', '1s');
                }, 2000);
            } else if (rand < 0.4) {
                // 随机对话
                this.showRandomDialogue('random');
            } else if (rand < 0.5 && this.state.hunger < 30) {
                this.showRandomDialogue('hungry');
            } else if (rand < 0.6 && this.state.happiness < 30) {
                this.showRandomDialogue('sad');
            } else if (rand < 0.7 && this.state.energy < 30) {
                this.showRandomDialogue('tired');
            }
        }, 5000);
    }

    // 状态衰减
    startStateDecay() {
        setInterval(() => {
            if (this.state.isSleeping) {
                // 睡觉时恢复精力，其他衰减变慢
                this.state.energy = Math.min(100, this.state.energy + 2);
                this.state.hunger = Math.max(0, this.state.hunger - 0.3);
                this.state.happiness = Math.max(0, this.state.happiness - 0.2);
            } else {
                this.state.hunger = Math.max(0, this.state.hunger - 1);
                this.state.happiness = Math.max(0, this.state.happiness - 0.5);
                this.state.energy = Math.max(0, this.state.energy - 0.8);
            }

            this.updateStatusBars();
        }, 3000);
    }

    // 喂食
    feed() {
        if (this.state.isSleeping) {
            this.showDialogue('艾露猫在睡觉呢...喵💤');
            return;
        }

        this.state.hunger = Math.min(100, this.state.hunger + 20);
        this.state.happiness = Math.min(100, this.state.happiness + 5);

        this.palico.classList.add('eating');
        this.mouth.classList.add('eating');

        this.updateStatusBars();
        this.showRandomDialogue('feed');

        // 食物特效
        const rect = this.palico.getBoundingClientRect();
        for (let i = 0; i < 3; i++) {
            setTimeout(() => {
                this.createEffect('heart', rect.left + rect.width / 2 + (Math.random() - 0.5) * 50, rect.top);
            }, i * 200);
        }

        setTimeout(() => {
            this.palico.classList.remove('eating');
            this.mouth.classList.remove('eating');
        }, 1000);
    }

    // 玩耍
    play() {
        if (this.state.isSleeping) {
            this.showDialogue('艾露猫在睡觉呢...喵💤');
            return;
        }

        if (this.state.energy < 20) {
            this.showDialogue('太累了，不想玩...喵');
            return;
        }

        this.state.happiness = Math.min(100, this.state.happiness + 25);
        this.state.energy = Math.max(0, this.state.energy - 15);
        this.state.hunger = Math.max(0, this.state.hunger - 10);

        this.palico.classList.add('happy');
        this.palico.classList.add('waving');

        this.updateStatusBars();
        this.showRandomDialogue('play');

        // 音符特效
        const rect = this.palico.getBoundingClientRect();
        for (let i = 0; i < 4; i++) {
            setTimeout(() => {
                this.createEffect('music-note', rect.left + rect.width / 2 + (Math.random() - 0.5) * 80, rect.top + 20);
            }, i * 300);
        }

        setTimeout(() => {
            this.palico.classList.remove('happy');
            this.palico.classList.remove('waving');
        }, 1500);
    }

    // 休息
    rest() {
        if (this.state.isSleeping) {
            this.state.isSleeping = false;
            this.palico.classList.remove('sleeping');
            this.leftEye.classList.remove('sleeping');
            this.rightEye.classList.remove('sleeping');
            this.mouth.classList.remove('happy');
            this.showDialogue('喵~ 睡醒了！精神满满！');
            return;
        }

        this.state.isSleeping = true;
        this.palico.classList.add('sleeping');
        this.leftEye.classList.add('sleeping');
        this.rightEye.classList.add('sleeping');
        this.mouth.classList.add('happy');

        this.showDialogue('晚安...喵💤');

        // ZZZ特效
        const rect = this.palico.getBoundingClientRect();
        this.sleepInterval = setInterval(() => {
            if (!this.state.isSleeping) {
                clearInterval(this.sleepInterval);
                return;
            }
            this.createEffect('zzz', rect.right - 10, rect.top + 20);
        }, 1500);
    }

    // 抚摸
    pet() {
        if (this.state.isSleeping) {
            this.showDialogue('呼噜呼噜...好舒服...💤');
            this.state.happiness = Math.min(100, this.state.happiness + 10);
            this.updateStatusBars();
            return;
        }

        this.state.happiness = Math.min(100, this.state.happiness + 15);

        this.palico.classList.add('happy');
        this.mouth.classList.add('happy');

        this.updateStatusBars();
        this.showRandomDialogue('pet');

        // 爱心特效
        const rect = this.palico.getBoundingClientRect();
        for (let i = 0; i < 5; i++) {
            setTimeout(() => {
                this.createEffect('heart', rect.left + rect.width / 2 + (Math.random() - 0.5) * 60, rect.top + Math.random() * 40);
            }, i * 150);
        }

        setTimeout(() => {
            this.palico.classList.remove('happy');
            this.mouth.classList.remove('happy');
        }, 1000);
    }
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', () => {
    new PalicoPet();
});
