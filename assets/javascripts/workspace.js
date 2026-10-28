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

  // Redmine's filter and option fieldsets become two popovers opened from the plain-language search bar.
  function placeIssuesPanel() {
    var panel = document.getElementById('gf-issues-panel');
    var form = document.getElementById('query_form');
    if (!panel || !form) { return; }
    form.parentNode.insertBefore(panel, form);
    var search = panel.querySelector('.gf-smart-search');
    var anchor = el('div', 'gf-query-anchor');
    search.parentNode.insertBefore(anchor, search.nextSibling);
    anchor.appendChild(form);
    form.classList.add('gf-query-popover');

    var toggles = panel.querySelectorAll('[data-gf-query-pane]');
    var count = panel.querySelector('[data-gf-filter-count]');
    // Redmine builds the filter rows in its own ready handler, which may run after this one.
    function updateCount() {
      if (!count) { return; }
      var active = form.querySelectorAll('fieldset#filters input[name="f[]"]:checked').length;
      count.textContent = active;
      count.hidden = active === 0;
    }
    window.setTimeout(updateCount, 0);
    form.addEventListener('change', updateCount);

    function close() {
      form.classList.remove('gf-open');
      toggles.forEach(function (t) { t.setAttribute('aria-expanded', 'false'); });
    }
    function open(pane, toggle) {
      form.setAttribute('data-gf-pane', pane);
      form.classList.add('gf-open');
      toggles.forEach(function (t) { t.setAttribute('aria-expanded', t === toggle ? 'true' : 'false'); });
      var first = form.querySelector('fieldset#' + pane + ' select, fieldset#' + pane + ' input:not([type=hidden])');
      if (first) { first.focus(); }
    }

    toggles.forEach(function (toggle) {
      toggle.addEventListener('click', function () {
        var pane = toggle.getAttribute('data-gf-query-pane');
        if (form.classList.contains('gf-open') && form.getAttribute('data-gf-pane') === pane) { close(); } else { open(pane, toggle); }
      });
    });
    document.addEventListener('mousedown', function (e) {
      if (!form.classList.contains('gf-open') || form.contains(e.target)) { return; }
      if (e.target.closest('[data-gf-query-pane], .ui-datepicker, .ui-autocomplete')) { return; }
      close();
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && form.classList.contains('gf-open')) {
        var toggle = panel.querySelector('[data-gf-query-pane][aria-expanded="true"]');
        close();
        if (toggle) { toggle.focus(); }
      }
    });
  }

  /* ---------- Status and priority icons ---------- */

  var Icons = {
    load: function () {
      var template = document.getElementById('gf-icon-templates');
      if (!template) { return false; }
      try { this.categories = JSON.parse(template.getAttribute('data-status-categories')) || {}; } catch (e) { this.categories = {}; }
      this.content = template.content;
      return true;
    },

    svg: function (attr, value) {
      var source = this.content.querySelector('[' + attr + '="' + value + '"] svg');
      return source ? source.cloneNode(true) : null;
    },

    classValue: function (node, pattern) {
      var match = (' ' + node.className + ' ').match(new RegExp(' ' + pattern + ' '));
      return match ? match[1] : null;
    },

    priorityLevel: function (name) {
      if (!name) { return null; }
      if (name === 'highest' || name === 'high1') { return 'urgent'; }
      if (name.indexOf('high') === 0) { return 'high'; }
      if (name.indexOf('low') === 0) { return 'low'; }
      return 'normal';
    },

    // Wraps the text of a cell in an icon + label pair.
    decorate: function (cell, kind, value) {
      if (!cell || !value || cell.querySelector('.gf-icon')) { return; }
      var icon = this.svg('data-' + kind, value);
      if (!icon) { return; }
      var wrap = el('span', (kind === 'status' ? 'gf-status gf-status-' : 'gf-prio gf-prio-') + value);
      wrap.appendChild(icon);
      var label = el('span');
      while (cell.firstChild) { label.appendChild(cell.firstChild); }
      wrap.appendChild(label);
      cell.appendChild(wrap);
    },

    apply: function (root) {
      if (!this.content && !this.load()) { return; }
      var self = this;
      (root || document).querySelectorAll('tr.issue, div.issue').forEach(function (row) {
        var statusId = self.classValue(row, 'status-([0-9]+)');
        // Rows carry both "priority-<id>" and "priority-<rank name>"; only the rank name matters here.
        var priority = self.priorityLevel(self.classValue(row, 'priority-([a-z]+[0-9]*)'));
        var isRow = row.tagName === 'TR';
        // On the issue page the attributes may have been moved to the side column.
        var scope = isRow ? row : (document.querySelector('.gf-issue-props') || row);
        self.decorate(scope.querySelector(isRow ? 'td.status' : '.attribute.status .value'), 'status', self.categories[statusId]);
        self.decorate(scope.querySelector(isRow ? 'td.priority' : '.attribute.priority .value'), 'priority', priority);
      });
    }
  };

  /* ---------- Issue page in two columns ---------- */

  // Moves the attribute block (and Redmine's sidebar on wide screens) into a sticky column on the right.
  function placeIssueColumns(i18n) {
    var body = document.body;
    if (!body.classList.contains('controller-issues') || !body.classList.contains('action-show')) { return; }
    var issue = document.querySelector('#content div.issue');
    if (!issue) { return; }

    var aside = document.querySelector('.gf-issue-aside');
    if (!aside) {
      var layout = el('div', 'gf-issue-layout');
      var main = el('div', 'gf-issue-main');
      aside = el('aside', 'gf-issue-aside');
      aside.setAttribute('aria-label', i18n.properties || '');
      issue.parentNode.insertBefore(layout, issue);
      var node = issue;
      while (node) {
        var next = node.nextSibling;
        main.appendChild(node);
        node = next;
      }
      var props = el('section', 'gf-issue-props');
      props.appendChild(el('h3', null, i18n.properties || ''));
      aside.appendChild(props);
      layout.appendChild(main);
      layout.appendChild(aside);

      var sidebar = document.getElementById('sidebar-wrapper');
      if (sidebar && window.matchMedia('(min-width: 900px)').matches) {
        var extra = el('div', 'gf-issue-sidebar');
        while (sidebar.firstChild) { extra.appendChild(sidebar.firstChild); }
        aside.appendChild(extra);
        body.classList.add('gf-issue-sidebar-moved');
      }
      body.classList.add('gf-issue-columns');
    }

    var attributes = issue.querySelector('.attributes');
    if (attributes) {
      var section = aside.querySelector('.gf-issue-props');
      var old = section.querySelector('.attributes');
      if (old) { old.remove(); }
      section.appendChild(attributes);
    }
  }

  function placeTransitions() {
    var bar = document.querySelector('.gf-transitions');
    var subject = document.querySelector('div.issue .subject');
    if (bar && subject) { subject.parentNode.insertBefore(bar, subject.nextSibling); }
  }

  /* ---------- In-place editing (issue page and preview) ---------- */

  // root: element holding the ".attributes .attribute.<key> .value" blocks; onSaved: called after each save.
  function InlineEdit(root, url, i18n, onSaved) {
    this.root = root;
    this.url = url;
    this.i18n = i18n || {};
    this.onSaved = onSaved;
  }

  InlineEdit.prototype = {
    load: function () {
      var self = this;
      return window.fetch(this.url, {headers: {Accept: 'application/json'}, credentials: 'same-origin'})
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (data) { if (data) { self.decorate(data); } })
        .catch(function () {});
    },

    decorate: function (data) {
      var self = this;
      this.lockVersion = data.lock_version;
      Object.keys(data.fields).forEach(function (key) {
        var block = self.root.querySelector('.attributes .attribute.' + CSS.escape(key));
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
          return self.onSaved();
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

    showError: function (value, message) {
      var note = el('div', 'gf-inline-error', message || this.i18n.error);
      note.setAttribute('role', 'alert');
      value.appendChild(note);
      window.setTimeout(function () { note.remove(); }, 6000);
    }
  };

  var IssuePage = {
    init: function (i18n) {
      this.i18n = i18n || this.i18n || {};
      placeIssueColumns(this.i18n);
      placeTransitions();
      Icons.apply();
      var config = document.getElementById('gf-inline');
      if (!config) { return; }
      var configI18n;
      try { configI18n = JSON.parse(config.getAttribute('data-i18n')) || {}; } catch (e) { configI18n = {}; }
      new InlineEdit(document.querySelector('.gf-issue-props') || document.querySelector('div.issue'),
        config.getAttribute('data-url'), configI18n, IssuePage.refresh).load();
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
          IssuePage.init();
        });
    }
  };

  /* ---------- Side preview of an issue ---------- */

  var PEEK_ICON = '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M14 4v16"/></svg>';

  var Peek = {
    init: function (nav, i18n) {
      this.urlTemplate = nav.getAttribute('data-peek-url');
      this.i18n = i18n;
      var self = this;
      // Capture phase, so the click neither selects the list row nor starts a kanban drag.
      ['mousedown', 'click'].forEach(function (type) {
        document.addEventListener(type, function (e) {
          var button = e.target.closest && e.target.closest('[data-gf-peek]');
          if (!button) { return; }
          e.stopPropagation();
          if (type === 'click') {
            e.preventDefault();
            self.open(button.getAttribute('data-gf-peek'), button);
          }
        }, true);
      });
      document.addEventListener('keydown', function (e) { if (self.panel) { self.onKey(e); } });
      this.addListButtons();
    },

    label: function (id) {
      return (this.i18n.peek_of || '').replace('__ID__', id);
    },

    addListButtons: function () {
      var self = this;
      document.querySelectorAll('tr.issue[id^="issue-"] td.subject').forEach(function (cell) {
        if (cell.querySelector('[data-gf-peek]')) { return; }
        var id = cell.parentNode.id.replace('issue-', '');
        var button = el('button', 'gf-peek-btn');
        button.type = 'button';
        button.setAttribute('data-gf-peek', id);
        button.setAttribute('aria-label', self.label(id));
        button.title = self.label(id);
        button.innerHTML = PEEK_ICON;
        cell.appendChild(button);
      });
    },

    ids: function () {
      var seen = [];
      document.querySelectorAll('[data-gf-peek]').forEach(function (node) {
        var id = node.getAttribute('data-gf-peek');
        if (seen.indexOf(id) < 0) { seen.push(id); }
      });
      return seen;
    },

    iconButton: function (className, label, svg) {
      var button = el('button', 'gf-peek-tool ' + className);
      button.type = 'button';
      button.setAttribute('aria-label', label);
      button.title = label;
      button.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true">' + svg + '</svg>';
      return button;
    },

    build: function () {
      var self = this;
      this.panel = el('aside', 'gf-peek');
      this.panel.setAttribute('role', 'dialog');
      this.panel.setAttribute('aria-labelledby', 'gf-peek-title');
      var bar = el('div', 'gf-peek-toolbar');
      bar.appendChild(el('span', 'gf-peek-name', this.i18n.peek || ''));
      this.prev = this.iconButton('gf-peek-prev', this.i18n.peek_previous || '', '<path d="m18 15-6-6-6 6"/>');
      this.next = this.iconButton('gf-peek-next', this.i18n.peek_next || '', '<path d="m6 9 6 6 6-6"/>');
      this.link = el('a', 'gf-peek-tool gf-peek-link');
      this.link.setAttribute('aria-label', this.i18n.peek_open || '');
      this.link.title = this.i18n.peek_open || '';
      this.link.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/></svg>';
      this.closeButton = this.iconButton('gf-peek-close', this.i18n.close || '', '<path d="M6 6l12 12M18 6 6 18"/>');
      [this.prev, this.next, this.link, this.closeButton].forEach(function (node) { bar.appendChild(node); });
      this.content = el('div', 'gf-peek-content');
      this.panel.appendChild(bar);
      this.panel.appendChild(this.content);
      document.body.appendChild(this.panel);
      document.body.classList.add('gf-peek-open');
      this.prev.addEventListener('click', function () { self.step(-1); });
      this.next.addEventListener('click', function () { self.step(1); });
      this.closeButton.addEventListener('click', function () { self.close(); });
      this.changed = false;
    },

    open: function (id, trigger) {
      if (!this.panel) {
        this.build();
        this.trigger = trigger || document.activeElement;
      }
      this.id = String(id);
      var ids = this.ids();
      var index = ids.indexOf(this.id);
      this.prev.disabled = index <= 0;
      this.next.disabled = index < 0 || index >= ids.length - 1;
      this.load(true);
    },

    load: function (focus) {
      var self = this;
      var id = this.id;
      return window.fetch(this.urlTemplate.replace('__ID__', id), {credentials: 'same-origin', headers: {Accept: 'text/html'}})
        .then(function (r) { return r.ok ? r.text() : Promise.reject(); })
        .then(function (html) {
          if (!self.panel || self.id !== id) { return; }
          self.content.innerHTML = html;
          var body = self.content.querySelector('.gf-peek-body');
          self.link.href = body.getAttribute('data-issue-url');
          new InlineEdit(body, body.getAttribute('data-inline-url'), self.i18n, function () {
            self.changed = true;
            return self.load(false);
          }).load();
          self.bindNoteForm(body);
          if (focus) {
            var title = self.content.querySelector('#gf-peek-title');
            title.setAttribute('tabindex', '-1');
            title.focus();
          }
        })
        .catch(function () {
          if (self.panel) { self.content.innerHTML = ''; self.content.appendChild(el('p', 'gf-inline-error', self.i18n.error || '')); }
        });
    },

    bindNoteForm: function (body) {
      var self = this;
      var form = body.querySelector('.gf-peek-note-form');
      if (!form) { return; }
      var textarea = form.querySelector('textarea');
      textarea.addEventListener('keydown', function (e) {
        // Redmine's own Ctrl+Enter handler would submit the form natively, bypassing the listener below.
        if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); e.stopPropagation(); form.requestSubmit(); }
      });
      form.addEventListener('submit', function (e) {
        e.preventDefault();
        if (!textarea.value.trim()) { textarea.focus(); return; }
        var button = form.querySelector('button[type=submit]');
        button.disabled = true;
        window.fetch(body.getAttribute('data-notes-url'), {
          method: 'POST',
          credentials: 'same-origin',
          headers: {Accept: 'application/json', 'X-CSRF-Token': csrfToken()},
          body: new URLSearchParams(new FormData(form))
        }).then(function (r) {
          return r.json().catch(function () { return {}; }).then(function (data) {
            if (!r.ok) { throw (data && data.error) || self.i18n.error; }
            self.changed = true;
            return self.load(false);
          });
        }).catch(function (message) {
          button.disabled = false;
          var note = el('p', 'gf-inline-error', message || self.i18n.error);
          note.setAttribute('role', 'alert');
          form.appendChild(note);
        });
      });
    },

    step: function (delta) {
      var ids = this.ids();
      var next = ids[ids.indexOf(this.id) + delta];
      if (next) { this.open(next); }
    },

    close: function () {
      if (!this.panel) { return; }
      this.panel.remove();
      this.panel = null;
      document.body.classList.remove('gf-peek-open');
      if (this.changed) { window.location.reload(); return; }
      if (this.trigger && this.trigger.focus) { this.trigger.focus(); }
    },

    onKey: function (e) {
      if (e.defaultPrevented) { return; }
      var typing = e.target.closest && e.target.closest('input, textarea, select, [contenteditable]');
      if (e.key === 'Escape' && !typing) { e.preventDefault(); this.close(); }
      else if (!typing && this.panel.contains(e.target) && (e.key === 'ArrowUp' || e.key === 'ArrowDown')) {
        e.preventDefault();
        this.step(e.key === 'ArrowUp' ? -1 : 1);
      }
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
    var nav = document.getElementById('gf-appnav');
    var i18n = {};
    if (nav) { try { i18n = JSON.parse(nav.getAttribute('data-i18n')) || {}; } catch (e) { i18n = {}; } }
    placeIssuesPanel();
    IssuePage.init(i18n);
    if (nav) { Peek.init(nav, i18n); }
    initProjects();
  });
})();
