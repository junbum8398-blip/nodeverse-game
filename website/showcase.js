// NODEVERSE - Interactive Showcase, 3D Tilt & Robot Companion

document.addEventListener('DOMContentLoaded', () => {
  // 1. Interactive Stage Filtering
  const filterBtns = document.querySelectorAll('.stage-filter-btn');
  const stageCards = document.querySelectorAll('.stage-card');

  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      const filter = btn.getAttribute('data-filter');
      stageCards.forEach(card => {
        const cat = card.getAttribute('data-category');
        if (filter === 'all' || cat === filter) {
          card.style.display = 'flex';
        } else {
          card.style.display = 'none';
        }
      });
    });
  });

  // 2. 3D Card Tilt & Holographic Glare
  stageCards.forEach(card => {
    // Add glare element if missing
    if (!card.querySelector('.stage-card-glare')) {
      const glare = document.createElement('div');
      glare.className = 'stage-card-glare';
      card.appendChild(glare);
    }

    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const centerX = rect.width / 2;
      const centerY = rect.height / 2;

      // Calculate tilt angles (limit between -9 and 9 deg)
      const rotateX = ((y - centerY) / centerY) * -9;
      const rotateY = ((x - centerX) / centerX) * 9;

      card.style.transform = `perspective(1000px) rotateX(${rotateX.toFixed(2)}deg) rotateY(${rotateY.toFixed(2)}deg) translateY(-8px) scale(1.02)`;

      const glare = card.querySelector('.stage-card-glare');
      if (glare) {
        glare.style.background = `radial-gradient(circle at ${x}px ${y}px, rgba(255,255,255,0.45) 0%, rgba(255,255,255,0) 65%)`;
      }
    });

    card.addEventListener('mouseleave', () => {
      card.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) translateY(0px) scale(1)';
    });
  });

  // 3. Floating Robot Companion Interactions
  const robotAvatarBtn = document.getElementById('robot-avatar-btn');
  const robotBubble = document.getElementById('robot-bubble');
  const bubbleText = document.getElementById('bubble-text');
  const bubbleClose = document.getElementById('bubble-close');

  const quotes = [
    { main: '안녕! 코딩 섬에 온 걸 환영해! 🏝️', sub: '(나를 클릭하면 코딩 꿀팁을 알려줄게!)' },
    { main: '상자를 밀어서 배열을 완성해봐! 📦', sub: '오른쪽 화면에 진짜 Python 코드가 적혀!' },
    { main: '스택은 접시 쌓기랑 똑같아! 🥞', sub: '맨 위에 놓은 것부터 꺼내 쓰는 LIFO!' },
    { main: '큐는 맛집 줄 서기랑 똑같아! 🍜', sub: '먼저 온 손님이 먼저 들어가는 FIFO!' },
    { main: '트리는 나뭇가지처럼 뻗어 나가! 🌳', sub: '루트(Root)에서 리프(Leaf)까지 탐색해봐!' },
    { main: '외우지 말고 나랑 같이 걸어! 🚀', sub: '10개 관문을 클리어하면 알고리즘 정복!' },
    { main: '삐빅-! 학습 로그 수집 중! 📡', sub: '너의 모든 플레이는 Kafka로 분석돼!' }
  ];

  let quoteIdx = 0;

  if (robotAvatarBtn && robotBubble && bubbleText) {
    // Click robot to cycle dialogues and bounce
    robotAvatarBtn.addEventListener('click', () => {
      // Bounce animation
      robotAvatarBtn.classList.remove('robot-clicked');
      void robotAvatarBtn.offsetWidth; // trigger reflow
      robotAvatarBtn.classList.add('robot-clicked');

      // Next dialogue
      quoteIdx = (quoteIdx + 1) % quotes.length;
      bubbleText.innerHTML = `${quotes[quoteIdx].main}<span class="bubble-sub">${quotes[quoteIdx].sub}</span>`;

      // Show bubble if closed
      robotBubble.style.display = 'block';
      robotBubble.style.opacity = '1';
      robotBubble.style.transform = 'scale(1)';
    });

    // Close button
    if (bubbleClose) {
      bubbleClose.addEventListener('click', (e) => {
        e.stopPropagation();
        robotBubble.style.opacity = '0';
        robotBubble.style.transform = 'scale(0.8)';
        setTimeout(() => {
          robotBubble.style.display = 'none';
        }, 200);
      });
    }
  }
});
