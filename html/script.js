// Utility for communication and notifications
let uiSettings = {
    locale: 'es',
    currency: '$',
    brand: {},
    testDrive: false,
    testDriveDuration: 90
};

const I18N = {
    es: {
        stat_speed: 'VELOCIDAD MÁXIMA',
        stat_accel: 'ACELERACIÓN',
        stat_brake: 'FRENADO',
        stat_handling: 'MANEJO',
        stats_note: 'Indicativos orientativos según categoría y modelo (no datos de juego en vivo).',
        finance_label: 'Financiación estimada',
        finance_note: 'Ejemplo a 48 meses sin entrada; tu banco o concesionario puede ofrecer otras condiciones.',
        finance_monthly: '~{amount}/mes',
        stock: 'DISPONIBLE EN STOCK',
        search_ph: 'Buscar por nombre o modelo…',
        sort_default: 'Orden: predeterminado',
        sort_price_asc: 'Precio: menor a mayor',
        sort_price_desc: 'Precio: mayor a menor',
        sort_name: 'Nombre: A–Z',
        test_drive: 'Prueba de manejo',
        buy: 'PROCEDER AL PAGO',
        payment_title: 'MÉTODO DE PAGO',
        pay_cash: 'EFECTIVO',
        pay_bank: 'BANCO',
        pay_cancel: 'CANCELAR',
        esc_close: 'Cerrar',
        staff_filter_ph: 'Filtrar lista…',
        models_count: 'Mostrando {n} modelos',
        models_empty: 'No hay vehículos en esta categoría',
        search_empty: 'Sin resultados para tu búsqueda',
        fav_add: 'Añadido a favoritos',
        fav_rem: 'Quitado de favoritos'
    },
    en: {
        stat_speed: 'TOP SPEED',
        stat_accel: 'ACCELERATION',
        stat_brake: 'BRAKING',
        stat_handling: 'HANDLING',
        stats_note: 'Illustrative ratings by category and model name (not live handling data).',
        finance_label: 'Estimated financing',
        finance_note: 'Example over 48 months, zero down; your bank or dealer may offer different terms.',
        finance_monthly: '~{amount}/mo',
        stock: 'IN STOCK',
        search_ph: 'Search by name or spawn code…',
        sort_default: 'Sort: default',
        sort_price_asc: 'Price: low to high',
        sort_price_desc: 'Price: high to low',
        sort_name: 'Name: A–Z',
        test_drive: 'Test drive',
        buy: 'CHECKOUT',
        payment_title: 'PAYMENT METHOD',
        pay_cash: 'CASH',
        pay_bank: 'BANK',
        pay_cancel: 'CANCEL',
        esc_close: 'Close',
        staff_filter_ph: 'Filter list…',
        models_count: 'Showing {n} models',
        models_empty: 'No vehicles in this category',
        search_empty: 'No matches for your search',
        fav_add: 'Added to favorites',
        fav_rem: 'Removed from favorites'
    }
};

function t(key, vars) {
    const loc = (uiSettings.locale === 'en' ? 'en' : 'es');
    let s = (I18N[loc] && I18N[loc][key]) || (I18N.es[key]) || key;
    if (vars && typeof vars === 'object') {
        Object.keys(vars).forEach(function (k) {
            s = s.replace('{' + k + '}', vars[k]);
        });
    }
    return s;
}

function hashStr(str) {
    let h = 0;
    const s = String(str || '');
    for (let i = 0; i < s.length; i++) {
        h = ((h << 5) - h) + s.charCodeAt(i);
        h |= 0;
    }
    return Math.abs(h);
}

function vehiclePerformanceProfile(vehicle) {
    const cat = normalizeVehicleCategory(vehicle.category) || 'deportivos';
    const base = hashStr(vehicle.model + '|' + cat);
    const bias = {
        superdeportivos: [88, 96, 82, 86],
        deportivos: [78, 88, 76, 82],
        deportivos_clasicos: [72, 70, 68, 74],
        musclecars: [80, 85, 72, 70],
        motos: [92, 94, 70, 88],
        electricos: [86, 96, 84, 80],
        suvs: [68, 72, 78, 74],
        sedanes: [70, 68, 76, 72],
        coupes: [74, 80, 74, 78],
        compactos: [62, 68, 70, 76]
    };
    const b = bias[cat] || [72, 76, 74, 76];
    const speed = Math.min(99, b[0] + (base % 7) - 3);
    const accel = Math.min(99, b[1] + ((base >> 3) % 7) - 3);
    const brake = Math.min(99, b[2] + ((base >> 6) % 7) - 3);
    const handling = Math.min(99, b[3] + ((base >> 9) % 7) - 3);
    return { speed, accel, brake, handling };
}

function applyStatsToDom(vehicle) {
    const p = vehiclePerformanceProfile(vehicle);
    const map = [
        ['stat-speed', p.speed],
        ['stat-accel', p.accel],
        ['stat-brake', p.brake],
        ['stat-handling', p.handling]
    ];
    map.forEach(function (item) {
        const idBar = item[0] + '-bar';
        const idPct = item[0] + '-pct';
        const elBar = document.getElementById(idBar);
        const elPct = document.getElementById(idPct);
        if (elBar) elBar.style.width = item[1] + '%';
        if (elPct) elPct.textContent = item[1] + '%';
    });
    const disc = document.getElementById('stats-disclaimer');
    if (disc) disc.textContent = t('stats_note');
}

function updateFinanceHint(price) {
    const n = Number(price) || 0;
    const label = document.getElementById('finance-label');
    const val = document.getElementById('finance-monthly');
    const note = document.getElementById('finance-note');
    if (label) label.textContent = t('finance_label');
    if (note) note.textContent = t('finance_note');
    if (val) {
        const months = 48;
        const approx = Math.max(0, Math.round(n * 1.08 / months));
        val.textContent = t('finance_monthly', { amount: Utils.formatMoney(approx) });
    }
}

const FAV_KEY = 'jgr_dealership_favorites';

function getFavorites() {
    try {
        const raw = localStorage.getItem(FAV_KEY);
        const arr = raw ? JSON.parse(raw) : [];
        return Array.isArray(arr) ? arr : [];
    } catch (e) {
        return [];
    }
}

function isFavorite(id) {
    return getFavorites().indexOf(Number(id)) !== -1;
}

function toggleFavoriteId(id) {
    const n = Number(id);
    let list = getFavorites().map(Number);
    const i = list.indexOf(n);
    if (i === -1) {
        list.push(n);
        Utils.notify(t('fav_add'), 'fa-heart');
    } else {
        list.splice(i, 1);
        Utils.notify(t('fav_rem'), 'fa-heart-broken');
    }
    localStorage.setItem(FAV_KEY, JSON.stringify(list));
}

const Utils = {
    post: function (endpoint, data, cb) {
        fetch('https://' + GetParentResourceName() + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        })
            .then(function (resp) { return resp.text(); })
            .then(function (text) {
                try {
                    return text && text.length ? JSON.parse(text) : {};
                } catch (e) {
                    return {};
                }
            })
            .then(function (resp) {
                if (cb) cb(resp);
            })
            .catch(function (e) { console.error('[JGR_Dealership]', e); });
    },

    closeUI: function () {
        Staff.hideDeleteModal();
        SortDropdown.close();
        document.getElementById('dealership-ui').classList.add('hidden');
        document.getElementById('staff-ui').classList.add('hidden');
        Utils.post('close', {});
    },

    notify: function (msg, icon) {
        const di = document.getElementById('dynamic-island');
        const diText = document.getElementById('di-text');
        const diIcon = document.getElementById('di-icon');

        diIcon.className = 'fas ' + (icon || 'fa-bell');
        diText.innerText = msg;

        di.classList.remove('hidden', 'hide');
        di.classList.add('show');

        setTimeout(function () {
            di.classList.remove('show');
            di.classList.add('hide');
            setTimeout(function () {
                di.classList.add('hidden');
                di.classList.remove('hide');
            }, 500);
        }, 3000);
    },

    formatMoney: function (amount) {
        const sym = uiSettings.currency || '$';
        return sym + String(amount).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    },

    escapeHtml: function (str) {
        if (str === null || str === undefined) return '';
        const s = String(str);
        const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
        return s.replace(/[&<>"']/g, function (c) { return map[c]; });
    }
};

let allVehicles = [];

function normalizeVehicleCategory(cat) {
    if (!cat) return cat;
    const legacy = {
        supers: 'superdeportivos',
        sedans: 'sedanes',
        motorcycles: 'motos'
    };
    return legacy[cat] || cat;
}

const SortDropdown = {
    isOpen: false,
    currentValue: 'default',
    bound: false,

    sortKeyForValue: function (v) {
        const m = {
            default: 'sort_default',
            'price-asc': 'sort_price_asc',
            'price-desc': 'sort_price_desc',
            'name-asc': 'sort_name'
        };
        return m[v] || 'sort_default';
    },

    labelForValue: function (v) {
        return t(this.sortKeyForValue(v));
    },

    refreshOptionLabels: function () {
        document.querySelectorAll('#sort-menu .sort-option-label').forEach(function (el) {
            const key = el.getAttribute('data-sort-key');
            if (key) el.textContent = t(key);
        });
        this.syncTriggerText();
        this.syncActiveOption();
    },

    syncTriggerText: function () {
        const el = document.getElementById('sort-trigger-text');
        if (el) el.textContent = this.labelForValue(this.currentValue);
    },

    syncActiveOption: function () {
        document.querySelectorAll('#sort-menu .sort-option').forEach(function (btn) {
            const on = btn.getAttribute('data-value') === SortDropdown.currentValue;
            btn.classList.toggle('is-active', on);
        });
    },

    syncDom: function () {
        const root = document.getElementById('vehicle-sort-root');
        const menu = document.getElementById('sort-menu');
        const trigger = document.getElementById('sort-trigger');
        if (menu) {
            if (this.isOpen) menu.classList.remove('hidden');
            else menu.classList.add('hidden');
        }
        if (root) root.classList.toggle('is-open', this.isOpen);
        if (trigger) trigger.setAttribute('aria-expanded', this.isOpen ? 'true' : 'false');
    },

    setValue: function (v, doRender) {
        this.currentValue = v || 'default';
        Dealership.sortMode = this.currentValue;
        this.syncTriggerText();
        this.syncActiveOption();
        if (doRender) Dealership.renderCatalog();
    },

    close: function () {
        this.isOpen = false;
        this.syncDom();
    },

    init: function () {
        if (this.bound) return;
        this.bound = true;
        const root = document.getElementById('vehicle-sort-root');
        const trigger = document.getElementById('sort-trigger');
        const menu = document.getElementById('sort-menu');
        if (!root || !trigger || !menu) return;

        trigger.addEventListener('click', function (e) {
            e.stopPropagation();
            SortDropdown.isOpen = !SortDropdown.isOpen;
            SortDropdown.syncDom();
        });

        menu.querySelectorAll('.sort-option').forEach(function (btn) {
            btn.addEventListener('click', function (e) {
                e.stopPropagation();
                const val = btn.getAttribute('data-value');
                SortDropdown.isOpen = false;
                SortDropdown.syncDom();
                SortDropdown.setValue(val, true);
            });
        });

        document.addEventListener('click', function (e) {
            if (!SortDropdown.isOpen) return;
            if (root.contains(e.target)) return;
            SortDropdown.isOpen = false;
            SortDropdown.syncDom();
        });
    }
};

function applyLocaleLabels() {
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
        const k = el.getAttribute('data-i18n');
        if (k) el.textContent = t(k);
    });
    const search = document.getElementById('vehicle-search');
    if (search) search.placeholder = t('search_ph');
    const staffS = document.getElementById('staff-search');
    if (staffS) staffS.placeholder = t('staff_filter_ph');
    const esc = document.getElementById('esc-hint-text');
    if (esc) esc.textContent = t('esc_close');
    SortDropdown.refreshOptionLabels();
    const td = document.getElementById('test-drive-label');
    if (td) td.textContent = t('test_drive');
    const buy = document.getElementById('buy-btn-label');
    if (buy) buy.textContent = t('buy');
    const pt = document.getElementById('payment-title');
    if (pt) pt.textContent = t('payment_title');
    const pc = document.getElementById('pay-cash-label');
    if (pc) pc.textContent = t('pay_cash');
    const pb = document.getElementById('pay-bank-label');
    if (pb) pb.textContent = t('pay_bank');
    const pcan = document.getElementById('pay-cancel-label');
    if (pcan) pcan.textContent = t('pay_cancel');

    const navLabels = {
        all: { es: 'Todos', en: 'All' },
        compactos: { es: 'Compactos', en: 'Compacts' },
        sedanes: { es: 'Sedanes', en: 'Sedans' },
        suvs: { es: 'SUVs', en: 'SUVs' },
        coupes: { es: 'Coupés', en: 'Coupés' },
        electricos: { es: 'Eléctricos', en: 'Electric' },
        musclecars: { es: 'Muscle cars', en: 'Muscle' },
        deportivos_clasicos: { es: 'Deportivos clásicos', en: 'Classic sports' },
        deportivos: { es: 'Deportivos', en: 'Sports' },
        superdeportivos: { es: 'Superdeportivos', en: 'Supercars' },
        motos: { es: 'Motos', en: 'Bikes' }
    };
    const loc = uiSettings.locale === 'en' ? 'en' : 'es';
    document.querySelectorAll('#categories-list li').forEach(function (li) {
        const cat = li.getAttribute('data-cat');
        const span = li.querySelector('span');
        if (!span || !cat) return;
        const entry = navLabels[cat];
        if (entry) span.textContent = entry[loc];
    });
}

function setBalances(balances) {
    const cashEl = document.getElementById('bal-cash');
    const bankEl = document.getElementById('bal-bank');
    const c = balances && typeof balances.cash === 'number' ? balances.cash : 0;
    const b = balances && typeof balances.bank === 'number' ? balances.bank : 0;
    if (cashEl) cashEl.textContent = Utils.formatMoney(c);
    if (bankEl) bankEl.textContent = Utils.formatMoney(b);
}

function applyBranding() {
    const b = uiSettings.brand || {};
    const h = document.querySelector('.brand-text h1');
    const sub = document.querySelector('.brand-text p');
    const tag = document.querySelector('.header-sub');
    if (h && b.title) h.textContent = b.title;
    if (sub && b.subtitle) sub.textContent = b.subtitle;
    if (tag && b.tagline) tag.textContent = b.tagline;
}

const Dealership = {
    currentCategory: 'all',
    currentVehicleInfo: null,
    searchQuery: '',
    sortMode: 'default',

    init: function (vehicles, balances, ui) {
        if (ui && typeof ui === 'object') {
            uiSettings = Object.assign({}, uiSettings, ui);
        }
        allVehicles = vehicles || [];
        document.getElementById('dealership-ui').classList.remove('hidden');
        document.getElementById('catalog-view').classList.remove('hidden');
        document.getElementById('preview-panel').classList.add('hidden');
        document.getElementById('staff-ui').classList.add('hidden');
        applyLocaleLabels();
        applyBranding();
        setBalances(balances);
        const tdBtn = document.getElementById('btn-test-drive');
        if (tdBtn) {
            if (uiSettings.testDrive) tdBtn.classList.remove('hidden');
            else tdBtn.classList.add('hidden');
        }
        const search = document.getElementById('vehicle-search');
        if (search) {
            search.value = '';
            this.searchQuery = '';
        }
        SortDropdown.setValue('default', false);
        SortDropdown.close();
        this.renderCatalog();
    },

    setCategory: function (cat, el) {
        document.querySelectorAll('#categories-list li').forEach(function (li) { li.classList.remove('is-active'); });
        el.classList.add('is-active');
        this.currentCategory = cat;

        const catNames = {
            all: { es: 'Catálogo completo', en: 'Full catalog' },
            compactos: { es: 'Compactos', en: 'Compacts' },
            sedanes: { es: 'Sedanes', en: 'Sedans' },
            suvs: { es: 'SUVs', en: 'SUVs' },
            coupes: { es: 'Coupés', en: 'Coupés' },
            electricos: { es: 'Eléctricos', en: 'Electric' },
            musclecars: { es: 'Muscle cars', en: 'Muscle' },
            deportivos_clasicos: { es: 'Deportivos clásicos', en: 'Classic sports' },
            deportivos: { es: 'Deportivos', en: 'Sports' },
            superdeportivos: { es: 'Superdeportivos', en: 'Super' },
            motos: { es: 'Motos', en: 'Motorcycles' }
        };
        const loc = uiSettings.locale === 'en' ? 'en' : 'es';
        const entry = catNames[cat];
        document.getElementById('current-cat-name').innerText = entry ? entry[loc] : (loc === 'en' ? 'Catalog' : 'Catálogo');

        this.renderCatalog();
    },

    getFilteredList: function () {
        let list = this.currentCategory === 'all'
            ? allVehicles.slice()
            : allVehicles.filter(function (v) {
                return normalizeVehicleCategory(v.category) === Dealership.currentCategory;
            });

        const q = (this.searchQuery || '').trim().toLowerCase();
        if (q) {
            list = list.filter(function (v) {
                const name = String(v.name || '').toLowerCase();
                const model = String(v.model || '').toLowerCase();
                return name.indexOf(q) !== -1 || model.indexOf(q) !== -1;
            });
        }

        if (this.sortMode === 'price-asc') {
            list.sort(function (a, b) { return Number(a.price) - Number(b.price); });
        } else if (this.sortMode === 'price-desc') {
            list.sort(function (a, b) { return Number(b.price) - Number(a.price); });
        } else if (this.sortMode === 'name-asc') {
            list.sort(function (a, b) { return String(a.name).localeCompare(String(b.name)); });
        }

        return list;
    },

    renderCatalog: function () {
        const container = document.getElementById('vehicles-container');
        container.innerHTML = '';

        const filtered = this.getFilteredList();
        const loc = uiSettings.locale === 'en' ? 'en' : 'es';
        const totalEl = document.getElementById('total-vehicles');

        if (filtered.length === 0) {
            const emptyMsg = (this.searchQuery || '').trim()
                ? t('search_empty')
                : t('models_empty');
            if (totalEl) totalEl.innerText = emptyMsg;
        } else {
            if (totalEl) totalEl.innerText = t('models_count', { n: String(filtered.length) });
        }

        const catLabel = function (cat) {
            const names = {
                compactos: { es: 'Compactos', en: 'Compacts' },
                sedanes: { es: 'Sedanes', en: 'Sedans' },
                suvs: { es: 'SUVs', en: 'SUVs' },
                coupes: { es: 'Coupés', en: 'Coupés' },
                electricos: { es: 'Eléctricos', en: 'Electric' },
                musclecars: { es: 'Muscle', en: 'Muscle' },
                deportivos_clasicos: { es: 'Clásicos', en: 'Classic' },
                deportivos: { es: 'Deportivos', en: 'Sports' },
                superdeportivos: { es: 'Super', en: 'Super' },
                motos: { es: 'Motos', en: 'Bikes' }
            };
            const c = normalizeVehicleCategory(cat);
            const e = names[c];
            return e ? e[loc] : (c || '—');
        };

        filtered.forEach(function (v) {
            const el = document.createElement('div');
            el.className = 'vehicle-card';
            el.onclick = function (e) {
                if (e.target.closest('.card-fav')) return;
                Dealership.previewVehicle(v);
            };

            const favActive = isFavorite(v.id) ? ' active' : '';
            el.innerHTML =
                '<div class="card-top">' +
                    '<span class="v-badge">' + Utils.escapeHtml(catLabel(v.category)) + '</span>' +
                    '<button type="button" class="card-fav' + favActive + '" data-fav-id="' + v.id + '" title="Favoritos">' +
                        '<i class="fas fa-heart"></i>' +
                    '</button>' +
                '</div>' +
                '<div class="v-info">' +
                    '<h3>' + Utils.escapeHtml(v.name) + '</h3>' +
                    '<p class="v-price">' + Utils.formatMoney(v.price) + '</p>' +
                    '<p class="v-model">' + Utils.escapeHtml(v.model) + '</p>' +
                '</div>';

            const favBtn = el.querySelector('.card-fav');
            if (favBtn) {
                favBtn.onclick = function (ev) {
                    ev.stopPropagation();
                    toggleFavoriteId(v.id);
                    favBtn.classList.toggle('active', isFavorite(v.id));
                };
            }
            container.appendChild(el);
        });
    },

    previewVehicle: function (v) {
        document.getElementById('catalog-view').classList.add('hidden');
        document.getElementById('preview-panel').classList.remove('hidden');

        document.getElementById('preview-name').innerText = v.name;
        document.getElementById('preview-price').innerText = Utils.formatMoney(v.price);
        const loc = uiSettings.locale === 'en' ? 'en' : 'es';
        const catNames = {
            compactos: { es: 'Compactos', en: 'Compacts' },
            sedanes: { es: 'Sedanes', en: 'Sedans' },
            suvs: { es: 'SUVs', en: 'SUVs' },
            coupes: { es: 'Coupés', en: 'Coupés' },
            electricos: { es: 'Eléctricos', en: 'Electric' },
            musclecars: { es: 'Muscle cars', en: 'Muscle' },
            deportivos_clasicos: { es: 'Deportivos clásicos', en: 'Classic sports' },
            deportivos: { es: 'Deportivos', en: 'Sports' },
            superdeportivos: { es: 'Superdeportivos', en: 'Supercars' },
            motos: { es: 'Motos', en: 'Motorcycles' }
        };
        const cKey = normalizeVehicleCategory(v.category);
        const badge = document.getElementById('preview-cat-badge');
        const code = document.getElementById('preview-model-code');
        if (badge) {
            const cn = catNames[cKey];
            badge.textContent = cn ? cn[loc] : (cKey || '—');
        }
        if (code) code.textContent = v.model || '—';
        const stock = document.getElementById('preview-stock-msg');
        if (stock) stock.textContent = t('stock');

        applyStatsToDom(v);
        updateFinanceHint(v.price);

        this.hidePaymentOptions();
        this.currentVehicleInfo = v;
        Utils.post('previewVehicle', { model: v.model });
    },

    backToCatalog: function () {
        document.getElementById('preview-panel').classList.add('hidden');
        document.getElementById('catalog-view').classList.remove('hidden');
        Utils.post('stopPreview', {});
    },

    rotate: function (dir) {
        Utils.post('rotateCam', { dir: dir });
    },

    changeColor: function (colorId) {
        Utils.post('changeColor', { colorId: colorId });
    },

    changeColorRgb: function (r, g, b) {
        Utils.post('changeColor', { r: r, g: g, b: b });
    },

    toggleLights: function () {
        Utils.post('togglePreviewLights', {});
    },

    showPaymentOptions: function () {
        document.getElementById('main-buy-btn').style.opacity = '0';
        document.getElementById('main-buy-btn').style.pointerEvents = 'none';
        document.getElementById('payment-options').classList.remove('hidden');
    },

    hidePaymentOptions: function () {
        document.getElementById('main-buy-btn').style.opacity = '1';
        document.getElementById('main-buy-btn').style.pointerEvents = 'all';
        document.getElementById('payment-options').classList.add('hidden');
    },

    buyCurrent: function (paymentType) {
        if (!this.currentVehicleInfo) return;
        Utils.post('buyVehicle', { vehicle: this.currentVehicleInfo, paymentType: paymentType });
        this.hidePaymentOptions();
    },

    startTestDrive: function () {
        if (!this.currentVehicleInfo || !uiSettings.testDrive) return;
        Utils.post('startTestDrive', { model: this.currentVehicleInfo.model });
    }
};

const Staff = {
    pendingDeleteId: null,
    staffFilter: '',

    init: function (vehicles) {
        allVehicles = vehicles || [];
        document.getElementById('staff-ui').classList.remove('hidden');
        document.getElementById('dealership-ui').classList.add('hidden');
        Staff.hideDeleteModal();
        const ss = document.getElementById('staff-search');
        if (ss) {
            ss.value = '';
            Staff.staffFilter = '';
        }
        applyLocaleLabels();
        this.renderList();
    },

    getFilteredStaffVehicles: function () {
        const q = (Staff.staffFilter || '').trim().toLowerCase();
        if (!q) return allVehicles;
        return allVehicles.filter(function (v) {
            const blob = (String(v.name) + ' ' + String(v.model) + ' ' + String(v.category) + ' ' + String(v.price)).toLowerCase();
            return blob.indexOf(q) !== -1;
        });
    },

    renderList: function () {
        const list = document.getElementById('staff-vehicles-list');
        list.innerHTML = '';

        const rows = Staff.getFilteredStaffVehicles();
        if (rows.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'staff-item';
            empty.style.justifyContent = 'center';
            empty.innerHTML = '<span style="color: rgba(255,255,255,0.45);">Sin resultados</span>';
            list.appendChild(empty);
            return;
        }

        rows.forEach(function (v) {
            const el = document.createElement('div');
            el.className = 'staff-item';
            el.dataset.vehicleId = String(v.id);
            el.innerHTML =
                '<div class="staff-item-info">' +
                    '<strong>' + Utils.escapeHtml(v.name) + ' (' + Utils.escapeHtml(v.model) + ')</strong>' +
                    '<span>' + Utils.formatMoney(v.price) + ' — ' + Utils.escapeHtml(v.category) + '</span>' +
                '</div>' +
                '<div class="staff-item-actions">' +
                    '<button type="button" class="btn-icon-staff btn-edit" data-action="edit" aria-label="Editar"><i class="fas fa-edit"></i></button>' +
                    '<button type="button" class="btn-icon-staff btn-delete" data-action="delete" aria-label="Eliminar"><i class="fas fa-trash"></i></button>' +
                '</div>';
            list.appendChild(el);
        });
    },

    editById: function (id) {
        const v = allVehicles.find(function (x) { return Number(x.id) === Number(id); });
        if (v) this.editForm(v);
    },

    save: function () {
        const id = document.getElementById('staff-id').value;
        const model = document.getElementById('staff-model').value;
        const name = document.getElementById('staff-name').value;
        const price = document.getElementById('staff-price').value;
        const category = document.getElementById('staff-category').value;

        if (!model || !name || !price) {
            Utils.notify('Rellena todos los campos', 'fa-times-circle');
            return;
        }

        const data = {
            id: id ? parseInt(id, 10) : null,
            model: model,
            name: name,
            price: parseInt(price, 10),
            category: category
        };

        if (id) {
            Utils.post('staffEdit', data);
        } else {
            Utils.post('staffAdd', data);
        }

        this.clearForm();
    },

    editForm: function (v) {
        const sel = document.getElementById('staff-category');
        const cat = normalizeVehicleCategory(v.category);
        document.getElementById('staff-id').value = v.id;
        document.getElementById('staff-model').value = v.model;
        document.getElementById('staff-name').value = v.name;
        document.getElementById('staff-price').value = v.price;
        sel.value = cat;
        if (!Array.prototype.some.call(sel.options, function (o) { return o.value === sel.value; })) {
            sel.value = 'deportivos';
        }
    },

    delete: function (id) {
        const n = Number(id);
        if (!Number.isFinite(n)) return;
        Staff.pendingDeleteId = n;
        const label = document.getElementById('staff-delete-label');
        const v = allVehicles.find(function (x) { return Number(x.id) === n; });
        if (v) {
            label.textContent = '¿Eliminar "' + v.name + '" (' + v.model + ') del catálogo? Esta acción no se puede deshacer.';
        } else {
            label.textContent = '¿Eliminar este vehículo del catálogo?';
        }
        document.getElementById('staff-delete-modal').classList.remove('hidden');
    },

    hideDeleteModal: function () {
        Staff.pendingDeleteId = null;
        const m = document.getElementById('staff-delete-modal');
        if (m) m.classList.add('hidden');
    },

    confirmDelete: function () {
        if (Staff.pendingDeleteId == null) return;
        const id = Staff.pendingDeleteId;
        Staff.hideDeleteModal();
        Utils.post('staffDelete', { id: id });
    },

    clearForm: function () {
        document.getElementById('staff-id').value = '';
        document.getElementById('staff-model').value = '';
        document.getElementById('staff-name').value = '';
        document.getElementById('staff-price').value = '';
        document.getElementById('staff-category').value = 'compactos';
    }
};

document.querySelectorAll('#categories-list li').forEach(function (li) {
    li.addEventListener('click', function () {
        Dealership.setCategory(li.getAttribute('data-cat'), li);
        Dealership.backToCatalog();
    });
});

document.getElementById('staff-delete-cancel').addEventListener('click', function () {
    Staff.hideDeleteModal();
});
document.getElementById('staff-delete-confirm').addEventListener('click', function () {
    Staff.confirmDelete();
});

document.getElementById('staff-vehicles-list').addEventListener('click', function (e) {
    const btn = e.target.closest('button[data-action]');
    if (!btn) return;
    const row = e.target.closest('.staff-item');
    if (!row || !row.dataset.vehicleId) return;
    const id = row.dataset.vehicleId;
    const action = btn.getAttribute('data-action');
    if (action === 'edit') Staff.editById(id);
    else if (action === 'delete') Staff.delete(id);
});

(function bindCatalogControls() {
    const search = document.getElementById('vehicle-search');
    if (search) {
        search.addEventListener('input', function () {
            Dealership.searchQuery = search.value;
            Dealership.renderCatalog();
        });
    }
    SortDropdown.init();
    const ref = document.getElementById('btn-refresh-bal');
    if (ref) {
        ref.addEventListener('click', function () {
            Utils.post('refreshBalances', {}, function (b) {
                setBalances(b);
            });
        });
    }
    const ss = document.getElementById('staff-search');
    if (ss) {
        ss.addEventListener('input', function () {
            Staff.staffFilter = ss.value;
            Staff.renderList();
        });
    }
})();

window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'openDealership') {
        Dealership.init(data.vehicles, data.balances, data.ui);
    }

    if (data.action === 'closeUI') {
        Staff.hideDeleteModal();
        SortDropdown.close();
        document.getElementById('dealership-ui').classList.add('hidden');
        document.getElementById('staff-ui').classList.add('hidden');
    }

    if (data.action === 'forceClose') {
        Staff.hideDeleteModal();
        SortDropdown.close();
        document.getElementById('dealership-ui').classList.add('hidden');
        document.getElementById('staff-ui').classList.add('hidden');
    }

    if (data.action === 'purchaseFailed') {
        Dealership.hidePaymentOptions();
        Utils.notify('No tienes suficiente dinero para esta compra', 'fa-wallet');
    }

    if (data.action === 'openStaffPanel') {
        Staff.init(data.vehicles);
    }

    if (data.action === 'refreshStaff') {
        if (!document.getElementById('staff-ui').classList.contains('hidden')) {
            Staff.init(data.vehicles);
        }
    }

    if (data.action === 'refreshDealership') {
        if (!document.getElementById('dealership-ui').classList.contains('hidden')) {
            allVehicles = data.vehicles || [];
            if (data.balances) setBalances(data.balances);
            Dealership.renderCatalog();
        }
    }
});

window.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape') return;
    if (SortDropdown.isOpen) {
        SortDropdown.close();
        event.preventDefault();
        return;
    }
    const delModal = document.getElementById('staff-delete-modal');
    if (delModal && !delModal.classList.contains('hidden')) {
        Staff.hideDeleteModal();
        event.preventDefault();
        return;
    }
    Utils.closeUI();
});
