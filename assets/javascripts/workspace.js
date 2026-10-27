(function () {
  'use strict';

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute('content') : '';
  }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (text !== undefined) { node.textContent = text; }
    return node;
  }

  /* ---------- Command palette ---------- */

  var Palette = {
    init: function () {
      var nav = document.getElementById('gf-appnav');
      if (!nav) { return; }
      this.url = nav.getAttribute('data-palette-url');
      try { this.i18n = JSON.parse(nav.getAttribute('data-i18n')) || {}; } catch (e) { this.i18n = {}; }
      var self = this;
      document.addEventListener('keydown', function (e) {
        if ((e.ctrlKey || e.metaKey) && !e.altKey && e.key.toLowerCase() === 'k') {
          e.preventDefault();
          self.isOpen() ? self.close() : self.open();
        }
      });
      document.addEventListener('click', function (e) {
        if (e.target.closest && e.target.closest('[data-gf-palette-open]')) {
          e.preventDefault();
          self.open();
        }
      });
    },

    isOpen: function () {
      return !!this.backdrop;
    },

    open: function () {
      if (this.isOpen()) { return; }
      var self = this;
      this.previousFocus = document.activeElement;
      this.backdrop = el('div', 'gf-palette-backdrop');
      var dialog = el('div', 'gf-palette');
      dialog.setAttribute('role', 'dialog');
      dialog.setAttribute('aria-modal', 'true');
      dialog.setAttribute('aria-label', this.i18n.title || 'Search');

      var inputRow = el('div', 'gf-palette-input');
      inputRow.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>';
      this.input = el('input');
      this.input.type = 'text';
      this.input.setAttribute('role', 'combobox');
      this.input.setAttribute('aria-expanded', 'true');
      this.input.setAttribute('aria-controls', 'gf-palette-results');
      this.input.setAttribute('aria-autocomplete', 'list');
      this.input.setAttribute('aria-label', this.i18n.title || 'Search');
      this.input.placeholder = this.i18n.placeholder || '';
      inputRow.appendChild(this.input);
      var esc = el('kbd', null, 'Esc');
      inputRow.appendChild(esc);

      this.results = el('div', 'gf-palette-results');
      this.results.id = 'gf-palette-results';
      this.results.setAttribute('role', 'listbox');

      var footer = el('div', 'gf-palette-footer');
      [this.i18n.hint_navigate, this.i18n.hint_open, this.i18n.hint_issue, this.i18n.hint_actions].forEach(function (hint) {
        if (hint) { footer.appendChild(el('span', null, hint)); }
      });

      dialog.appendChild(inputRow);
      dialog.appendChild(this.results);
      dialog.appendChild(footer);
      this.backdrop.appendChild(dialog);
      document.body.appendChild(this.backdrop);

      this.backdrop.addEventListener('mousedown', function (e) {
        if (e.target === self.backdrop) { self.close(); }
      });
      this.input.addEventListener('input', function () { self.schedule(); });
      this.input.addEventListener('keydown', function (e) { self.onKey(e); });
      this.input.focus();
      this.fetch('');
    },

    close: function () {
      if (!this.backdrop) { return; }
      this.backdrop.remove();
      this.backdrop = null;
      if (this.previousFocus && this.previousFocus.focus) { this.previousFocus.focus(); }
    },

    schedule: function () {
      var self = this;
      window.clearTimeout(this.timer);
      this.timer = window.setTimeout(function () { self.fetch(self.input.value); }, 120);
    },

    fetch: function (text) {
      var self = this;
      var requestId = (this.requestId || 0) + 1;
      this.requestId = requestId;
      var url = this.url + (this.url.indexOf('?') >= 0 ? '&' : '?') + 'q=' + encodeURIComponent(text);
      window.fetch(url, {headers: {Accept: 'application/json'}, credentials: 'same-origin'})
        .then(function (r) { return r.ok ? r.json() : {sections: []}; })
        .then(function (data) { if (self.requestId === requestId && self.isOpen()) { self.render(data.sections || []); } })
        .catch(function () {});
    },

    render: function (sections) {
      var self = this;
      this.items = [];
      this.results.innerHTML = '';
      if (!sections.length) {
        this.results.appendChild(el('p', 'gf-palette-empty', this.i18n.empty || ''));
        return;
      }
      sections.forEach(function (section) {
        self.results.appendChild(el('div', 'gf-palette-section', section.title));
        section.items.forEach(function (item) {
          var node = el(item.url ? 'a' : 'div', 'gf-palette-item');
          node.setAttribute('role', 'option');
          node.id = 'gf-palette-item-' + self.items.length;
          if (item.url) { node.href = item.url; }
          var badge = el('span', 'gf-palette-badge', item.badge || '');
          badge.setAttribute('aria-hidden', 'true');
          if (item.color) { badge.style.background = item.color; }
          var text = el('span', 'gf-palette-text');
          text.appendChild(el('span', 'gf-palette-label', item.label));
          if (item.hint) { text.appendChild(el('span', 'gf-palette-hint', item.hint)); }
          node.appendChild(badge);
          node.appendChild(text);
          var index = self.items.length;
          node.addEventListener('mousemove', function () { self.select(index); });
          node.addEventListener('click', function (e) { e.preventDefault(); self.activate(index); });
          self.results.appendChild(node);
          self.items.push({node: node, data: item});
        });
      });
      this.select(0);
    },

    select: function (index) {
      if (!this.items || !this.items.length) { return; }
      this.selected = (index + this.items.length) % this.items.length;
      var self = this;
      this.items.forEach(function (item, i) {
        item.node.setAttribute('aria-selected', i === self.selected ? 'true' : 'false');
      });
      var current = this.items[this.selected].node;
      this.input.setAttribute('aria-activedescendant', current.id);
      current.scrollIntoView({block: 'nearest'});
    },

    activate: function (index) {
      var item = this.items && this.items[index];
      if (!item) { return; }
      if (item.data.js === 'toggle-theme') {
        var toggle = document.querySelector('.gf-theme-toggle');
        if (toggle) { toggle.click(); }
        this.close();
      } else if (item.data.url) {
        window.location.href = item.data.url;
      }
    },

    onKey: function (e) {
      if (e.key === 'ArrowDown') { e.preventDefault(); this.select(this.selected + 1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); this.select(this.selected - 1); }
      else if (e.key === 'Enter') { e.preventDefault(); this.activate(this.selected); }
      else if (e.key === 'Escape') { e.preventDefault(); this.close(); }
      else if (e.key === 'Tab') { e.preventDefault(); this.select(this.selected + (e.shiftKey ? -1 : 1)); }
    }
  };

  /* ---------- Placement of injected blocks ---------- */

  function placeIssuesPanel() {
    var panel = document.getElementById('gf-issues-panel');
    var form = document.getElementById('query_form');
    if (!panel || !form) { return; }
    form.parentNode.insertBefore(panel, form);
    var filters = form.querySelector('fieldset#filters');
    if (filters && !filters.classList.contains('collapsed')) {
      var legend = filters.querySelector('legend');
      if (legend && typeof window.toggleFieldset === 'function') { window.toggleFieldset(legend); }
    }
  }

  function placeTransitions() {
    var bar = document.querySelector('.gf-transitions');
    var subject = document.querySelector('div.issue .subject');
    if (bar && subject) { subject.parentNode.insertBefore(bar, subject.nextSibling); }
  }

  /* ---------- In-place editing on the issue page ---------- */

  var InlineEdit = {
    init: function () {
      var config = document.getElementById('gf-inline');
      if (!config) { return; }
      this.url = config.getAttribute('data-url');
      try { this.i18n = JSON.parse(config.getAttribute('data-i18n')) || {}; } catch (e) { this.i18n = {}; }
      var self = this;
      window.fetch(this.url, {headers: {Accept: 'application/json'}, credentials: 'same-origin'})
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (data) { if (data) { self.decorate(data); } })
        .catch(function () {});
    },

    decorate: function (data) {
      var self = this;
      this.lockVersion = data.lock_version;
      Object.keys(data.fields).forEach(function (key) {
        var block = document.querySelector('div.issue .attributes .attribute.' + CSS.escape(key));
        var value = block && block.querySelector('.value');
        if (!value) { return; }
        value.classList.add('gf-editable');
        value.setAttribute('role', 'button');
        value.setAttribute('tabindex', '0');
        value.setAttribute('title', self.i18n.edit || '');
        var label = block.querySelector('.label');
        value.setAttribute('aria-label', (label ? label.textContent.replace(/:\s*$/, '') + ' : ' : '') + (self.i18n.edit || ''));
        var open = function (e) {
          if (e.type === 'click' && e.target.closest('a') && (e.ctrlKey || e.metaKey || e.shiftKey)) { return; }
          if (value.classList.contains('gf-editing')) { return; }
          e.preventDefault();
          self.open(value, data.fields[key]);
        };
        value.addEventListener('click', open);
        value.addEventListener('keydown', function (e) {
          if ((e.key === 'Enter' || e.key === ' ') && e.target === value) { open(e); }
        });
      });
    },

    open: function (value, field) {
      if (value.classList.contains('gf-editing')) { return; }
      var self = this;
      var original = value.innerHTML;
      var editor;
      if (field.type === 'select') {
        editor = el('select');
        if (field.blank) { editor.appendChild(new Option('—', '')); }
        field.options.forEach(function (option) {
          editor.appendChild(new Option(option[0], option[1], false, option[1] === field.value));
        });
        if (!field.options.some(function (o) { return o[1] === field.value; })) { editor.value = ''; }
      } else {
        editor = el('input');
        editor.type = field.type === 'number' ? 'number' : (field.type === 'date' ? 'date' : 'text');
        if (field.step) { editor.step = field.step; }
        if (field.min !== undefined) { editor.min = field.min; }
        editor.value = field.value === null || field.value === undefined ? '' : field.value;
      }
      editor.className = 'gf-inline-editor';
      editor.setAttribute('aria-label', value.getAttribute('aria-label') || '');

      value.classList.add('gf-editing');
      value.removeAttribute('role');
      value.innerHTML = '';
      value.appendChild(editor);
      editor.focus();

      var done = false;
      var cancel = function () {
        if (done) { return; }
        done = true;
        value.innerHTML = original;
        value.classList.remove('gf-editing');
        value.setAttribute('role', 'button');
        value.focus();
      };
      var commit = function () {
        if (done) { return; }
        if (String(editor.value) === String(field.value === null || field.value === undefined ? '' : field.value)) { cancel(); return; }
        done = true;
        editor.disabled = true;
        value.classList.add('gf-saving');
        self.save(field, editor.value).then(function () {
          return self.refresh();
        }).catch(function (message) {
          value.innerHTML = original;
          value.classList.remove('gf-editing', 'gf-saving');
          value.setAttribute('role', 'button');
          self.showError(value, message);
        });
      };

      editor.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') { e.preventDefault(); cancel(); }
        else if (e.key === 'Enter') { e.preventDefault(); commit(); }
      });
      if (field.type === 'select') {
        editor.addEventListener('change', commit);
      }
      editor.addEventListener('blur', function () {
        window.setTimeout(function () { field.type === 'select' ? cancel() : commit(); }, 120);
      });
    },

    save: function (field, newValue) {
      var self = this;
      return window.fetch(this.url, {
        method: 'PATCH',
        credentials: 'same-origin',
        headers: {'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrfToken()},
        body: JSON.stringify({attribute: field.attribute, value: newValue, lock_version: this.lockVersion})
      }).then(function (r) {
        return r.json().catch(function () { return {}; }).then(function (data) {
          if (!r.ok) { throw (data && data.error) || self.i18n.error; }
          self.lockVersion = data.lock_version;
        });
      });
    },

    // Reloads the issue block and history so derived values and the journal stay accurate.
    refresh: function () {
      return window.fetch(window.location.href, {credentials: 'same-origin', headers: {Accept: 'text/html'}})
        .then(function (r) { return r.text(); })
        .then(function (html) {
          var doc = new DOMParser().parseFromString(html, 'text/html');
          ['div.issue', '#history', '#content > .contextual'].forEach(function (selector) {
            var fresh = doc.querySelector(selector);
            var current = document.querySelector(selector);
            if (fresh && current) { current.replaceWith(document.importNode(fresh, true)); }
          });
          placeTransitions();
          InlineEdit.init();
        });
    },

    showError: function (value, message) {
      var note = el('div', 'gf-inline-error', message || this.i18n.error);
      note.setAttribute('role', 'alert');
      value.appendChild(note);
      window.setTimeout(function () { note.remove(); }, 6000);
    }
  };

  /* ---------- Projects page ---------- */

  function initProjects() {
    var page = document.querySelector('[data-gf-projects]');
    if (!page) { return; }
    var search = page.querySelector('[data-gf-project-filter]');
    var chips = page.querySelectorAll('[data-gf-project-chip]');
    var cards = page.querySelectorAll('.gf-project-card');
    var empty = page.querySelector('[data-gf-projects-empty]');
    var filter = 'all';

    function apply() {
      var term = (search.value || '').toLowerCase().trim();
      var visible = 0;
      cards.forEach(function (card) {
        var ok = (!term || card.getAttribute('data-name').indexOf(term) >= 0) &&
          (filter === 'all' || card.getAttribute('data-' + filter) === 'true');
        card.hidden = !ok;
        if (ok) { visible++; }
      });
      if (empty) { empty.hidden = visible > 0 || cards.length === 0; }
    }

    search.addEventListener('input', apply);
    chips.forEach(function (chip) {
      chip.addEventListener('click', function () {
        filter = chip.getAttribute('data-gf-project-chip');
        chips.forEach(function (c) { c.setAttribute('aria-pressed', c === chip ? 'true' : 'false'); });
        apply();
      });
    });

    page.addEventListener('click', function (e) {
      var star = e.target.closest('[data-gf-bookmark]');
      if (!star) { return; }
      var on = star.getAttribute('aria-pressed') !== 'true';
      window.fetch(star.getAttribute('data-gf-bookmark'), {
        method: on ? 'POST' : 'DELETE',
        credentials: 'same-origin',
        headers: {'X-CSRF-Token': csrfToken(), Accept: 'text/javascript'}
      }).then(function (r) {
        if (!r.ok) { return; }
        var label = star.getAttribute(on ? 'data-label-on' : 'data-label-off');
        star.setAttribute('aria-pressed', on ? 'true' : 'false');
        star.setAttribute('aria-label', label);
        star.setAttribute('title', label);
        star.closest('.gf-project-card').setAttribute('data-bookmarked', on ? 'true' : 'false');
        apply();
      });
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (document.getElementById('gf-appnav')) { document.body.classList.add('gf-has-appnav'); }
    Palette.init();
    placeIssuesPanel();
    placeTransitions();
    InlineEdit.init();
    initProjects();
  });
})();
