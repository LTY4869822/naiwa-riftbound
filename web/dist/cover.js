/* Scene previews are cosmetic. Real game route selection stays in Godot. */
(() => {
  'use strict';
  const cover = document.getElementById('cover');
  const realms = [...document.querySelectorAll('.realm')];
  const scenes = [...document.querySelectorAll('.scene')];
  for (const button of realms) button.addEventListener('click', () => {
    cover.dataset.realm = button.dataset.realm;
    for (const item of realms) {
      const selected = item === button;
      item.classList.toggle('active', selected);
      item.setAttribute('aria-pressed', String(selected));
    }
    for (const image of scenes) image.classList.toggle('current', image.dataset.scene === button.dataset.realm);
  });
  const guide = document.getElementById('guide');
  const guideButton = document.getElementById('guide-open');
  guideButton.addEventListener('click', () => guide.showModal());
  document.getElementById('guide-close').addEventListener('click', () => guide.close());
  guide.addEventListener('close', () => {if (!cover.hidden) guideButton.focus();});
  guide.addEventListener('click', event => {
    const box = guide.getBoundingClientRect();
    if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) guide.close();
  });
  const pet = document.getElementById('pet-greet');
  let greeting;
  pet.addEventListener('click', () => {
    if (pet.classList.contains('greeting')) return;
    pet.classList.add('greeting');
    greeting = setTimeout(() => pet.classList.remove('greeting'), 1000);
  });
  window.addEventListener('pagehide', () => clearTimeout(greeting));
  document.addEventListener('keydown', event => {
    if (cover.hidden || guide.open || event.repeat || event.ctrlKey || event.metaKey || event.altKey) return;
    if (event.key === '?' && !event.target.closest('button,a,input,textarea')) {
      event.preventDefault(); guide.showModal();
    }
    if (event.key === 'Enter' && !event.target.closest('button,a,input,textarea')) {
      event.preventDefault();
      const start = document.getElementById('start');
      if (!start.hidden && !start.disabled) start.click();
    }
  });
})();
