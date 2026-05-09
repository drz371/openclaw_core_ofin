const blogPosts = [
  {
    id: 1,
    title: "WebGL粒子效果实践",
    summary: "探索WebGL在粒子系统中的强大表现力，打造震撼的视觉特效。从基础渲染到复杂物理模拟，全面解析粒子效果实现原理。",
    category: "tech",
    date: "2026-05-01",
    tags: ["WebGL", "Canvas", "动画"],
    color: "#00d4ff"
  },
  {
    id: 2,
    title: "勇者斗恶龙系列回顾",
    summary: "从FC时代到现代主机，回顾勇者斗恶龙系列三十年的辉煌历程。那些陪伴我们成长的经典瞬间与感动。",
    category: "game",
    date: "2026-04-28",
    tags: ["RPG", "经典", "怀旧"],
    color: "#ff006e"
  },
  {
    id: 3,
    title: "米山舞的色彩运用解析",
    summary: "深入分析米山舞作品中独特的色彩搭配技巧，高对比度配色与光影效果的完美结合，为数字艺术带来全新可能。",
    category: "design",
    date: "2026-04-25",
    tags: ["插画", "色彩", "设计"],
    color: "#7b2ff7"
  },
  {
    id: 4,
    title: "独立开发者的日常",
    summary: "代码、咖啡与深夜的灵感。记录作为一名独立开发者的真实生活，如何在自由与自律之间找到平衡。",
    category: "life",
    date: "2026-04-20",
    tags: ["生活", "独立开发", "日常"],
    color: "#ffb700"
  },
  {
    id: 5,
    title: "像素艺术与复古美学",
    summary: "在高清时代，像素艺术依然拥有独特的魅力。探讨如何用现代技术重现8-bit时代的视觉风格。",
    category: "design",
    date: "2026-04-15",
    tags: ["像素", "复古", "美术"],
    color: "#7b2ff7"
  },
  {
    id: 6,
    title: "用JavaScript实现回合制RPG",
    summary: "从零开始用原生JavaScript构建一个完整的回合制RPG战斗系统，包含角色、怪物、技能和升级系统。",
    category: "tech",
    date: "2026-04-10",
    tags: ["JavaScript", "游戏开发", "RPG"],
    color: "#00d4ff"
  },
  {
    id: 7,
    title: "塞尔达传说：荒野之息的设计哲学",
    summary: "任天堂如何用开放世界重新定义冒险游戏。从物理引擎到谜题设计，全面解析旷野之息的成功秘诀。",
    category: "game",
    date: "2026-04-05",
    tags: ["任天堂", "开放世界", "设计"],
    color: "#ff006e"
  },
  {
    id: 8,
    title: "深夜食堂与代码灵感",
    summary: "有时候最好的代码灵感不是在电脑前想出来的。分享那些在散步、做饭、甚至洗澡时迸发的创意瞬间。",
    category: "life",
    date: "2026-04-01",
    tags: ["灵感", "生活", "创意"],
    color: "#ffb700"
  }
];

document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  renderPosts(blogPosts);
  initSearch();
  initCategoryFilters();
  initParticles();
  initGamePage();
});

function initNavigation() {
  const navItems = document.querySelectorAll('.nav-item');
  const pages = document.querySelectorAll('.page');
  
  navItems.forEach(item => {
    item.addEventListener('click', () => {
      const targetPage = item.dataset.page;
      
      navItems.forEach(nav => nav.classList.remove('active'));
      item.classList.add('active');
      
      pages.forEach(page => {
        if (page.id === `${targetPage}-page`) {
          page.classList.add('active');
        } else {
          page.classList.remove('active');
        }
      });
    });
  });
}

function renderPosts(posts) {
  const grid = document.getElementById('postsGrid');
  grid.innerHTML = '';
  
  posts.forEach((post, index) => {
    const card = document.createElement('div');
    card.className = 'post-card';
    card.style.animationDelay = `${index * 0.1}s`;
    card.innerHTML = `
      <span class="post-category ${post.category}">${getCategoryName(post.category)}</span>
      <h3 class="post-title">${post.title}</h3>
      <p class="post-summary">${post.summary}</p>
      <div class="post-meta">
        <span>${post.date}</span>
        <div class="post-tags">
          ${post.tags.map(tag => `<span class="tag">${tag}</span>`).join('')}
        </div>
      </div>
    `;
    grid.appendChild(card);
  });
}

function getCategoryName(category) {
  const names = {
    tech: '技术',
    game: '游戏',
    design: '设计',
    life: '生活'
  };
  return names[category] || category;
}

function initSearch() {
  const searchInput = document.getElementById('searchInput');
  searchInput.addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase();
    const filtered = blogPosts.filter(post => 
      post.title.toLowerCase().includes(query) || 
      post.summary.toLowerCase().includes(query) ||
      post.tags.some(tag => tag.toLowerCase().includes(query))
    );
    renderPosts(filtered);
  });
}

function initCategoryFilters() {
  const filterBtns = document.querySelectorAll('.filter-btn');
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      
      const category = btn.dataset.category;
      if (category === 'all') {
        renderPosts(blogPosts);
      } else {
        const filtered = blogPosts.filter(post => post.category === category);
        renderPosts(filtered);
      }
    });
  });
}

function initParticles() {
  const container = document.getElementById('particle-canvas');
  const particleCount = 30;
  
  for (let i = 0; i < particleCount; i++) {
    const particle = document.createElement('div');
    particle.className = 'particle';
    particle.style.left = `${Math.random() * 100}%`;
    particle.style.animationDuration = `${10 + Math.random() * 20}s`;
    particle.style.animationDelay = `${Math.random() * 10}s`;
    container.appendChild(particle);
  }
}

function initGamePage() {
  if (typeof PixelGame !== 'undefined') {
    window.game = new PixelGame();
  }
}
