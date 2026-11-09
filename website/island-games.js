(() => {
  const board = document.getElementById('play-board');
  const message = document.getElementById('play-message');
  const progress = document.getElementById('play-progress');
  const stack = [];

  function say(text, success = false) {
    message.textContent = text;
    message.classList.toggle('success', success);
  }

  function render() {
    const remaining = [10, 20, 30].filter(value => !stack.includes(value));
    board.innerHTML = `
      <div class="mini-scene stack-scene">
        <div class="scene-label">DATA STRUCTURE · STACK</div>
        <div class="stack-target">목표: 위 <b>30</b> · <b>20</b> · <b>10</b> 아래</div>
        <div class="stack-tower">${[...stack].reverse().map(value => `<div class="stack-crate">${value}</div>`).join('') || '<span class="empty-stack">비어 있는 상자 탑</span>'}</div>
        <div class="stack-base">상자 탑</div>
      </div>
      <div class="mini-panel">
        <h4>입고할 상자</h4>
        <p>버튼을 누르면 상자가 탑의 맨 위에 올라가요.</p>
        <div class="crate-choices">${remaining.map(value => `<button type="button" class="crate-choice" data-push="${value}">📦 ${value} PUSH</button>`).join('') || '<span>모든 상자를 사용했어요.</span>'}</div>
        <button type="button" id="pop-crate" class="secondary-action" ${stack.length ? '' : 'disabled'}>↶ 맨 위 상자 POP</button>
        <p class="concept">마지막에 넣은 것을 먼저 꺼내는 규칙이 <b>LIFO</b>예요.</p>
      </div>`;
    board.querySelectorAll('[data-push]').forEach(button => {
      button.addEventListener('click', () => {
        const value = Number(button.dataset.push);
        stack.push(value);
        render();
        if (stack.join(',') === '10,20,30') {
          progress.textContent = '스테이지 완료 ✓';
          say('상자 탑 완성! 마지막에 넣은 30이 맨 위에 있어요.', true);
        } else {
          progress.textContent = `${stack.length} / 3 상자`;
          say(`${value} 상자를 맨 위에 올렸어요.`);
        }
      });
    });
    board.querySelector('#pop-crate').addEventListener('click', () => {
      const value = stack.pop();
      progress.textContent = `${stack.length} / 3 상자`;
      render();
      say(`${value} 상자를 맨 위에서 꺼냈어요.`);
    });
  }

  document.getElementById('play-hint').addEventListener('click', () => say('10, 20, 30 순서로 PUSH해 보세요. 잘못 쌓으면 POP으로 맨 위부터 꺼낼 수 있어요.'));
  document.getElementById('play-reset').addEventListener('click', () => {
    stack.length = 0;
    progress.textContent = '준비';
    render();
    say('처음 상태로 돌아왔어요.');
  });
  render();
})();
