// Utility for communication and notifications
const Utils = {
    post: function (endpoint, data = {}, cb) {
        fetch(`https://${GetParentResourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        })
            .then((resp) => resp.text())
            .then((text) => {
                try {
                    return text && text.length ? JSON.parse(text) : {};
                } catch (e) {
                    return {};
                }
            })
            .then((resp) => {
                if (cb) cb(resp);
            })
            .catch((e) => console.error('[JGR_Dealership]', e));
    },

    closeUI: function () {
        Staff.hideDeleteModal();
        document.getElementById('dealership-ui').classList.add('hidden');
        document.getElementById('staff-ui').classList.add('hidden');
        Utils.post('close', {});
    },

    notify: function (msg, icon = 'fa-bell') {
        const di = document.getElementById('dynamic-island');
        const diText = document.getElementById('di-text');
        const diIcon = document.getElementById('di-icon');

        diIcon.className = `fas ${icon}`;
        diText.innerText = msg;

        di.classList.remove('hidden', 'hide');
        di.classList.add('show');

        setTimeout(() => {
            di.classList.remove('show');
            di.classList.add('hide');
            setTimeout(() => {
                di.classList.add('hidden');
                di.classList.remove('hide');
            }, 500);
        }, 3000);
    },

    formatMoney: function (amount) {
        return '$' + amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    },

    escapeHtml: function (str) {
        if (str === null || str === undefined) return '';
        const s = String(str);
        const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
        return s.replace(/[&<>"']/g, (c) => map[c]);
    }
};

// Global Data
let allVehicles = [];

/** Normaliza categorías antiguas de BD a las claves actuales */
function normalizeVehicleCategory(cat) {
    if (!cat) return cat;
    const legacy = {
        supers: 'superdeportivos',
        sedans: 'sedanes',
        motorcycles: 'motos'
    };
    return legacy[cat] || cat;
}

// Dealership Client Logic
const Dealership = {
    currentCategory: 'all',
    currentVehicleInfo: null,

    init: function (vehicles) {
        allVehicles = vehicles;
        document.getElementById('dealership-ui').classList.remove('hidden');
        document.getElementById('catalog-view').classList.remove('hidden');
        document.getElementById('preview-panel').classList.add('hidden');
        document.getElementById('staff-ui').classList.add('hidden');
        this.renderCatalog();
    },

    setCategory: function (cat, el) {
        document.querySelectorAll('#categories-list li').forEach(li => li.classList.remove('active'));
        el.classList.add('active');
        this.currentCategory = cat;

        // Update Header Title
        const catNames = {
            'all': 'Catálogo completo',
            'compactos': 'Compactos',
            'sedanes': 'Sedanes',
            'suvs': 'SUVs',
            'coupes': 'Coupés',
            'electricos': 'Eléctricos',
            'musclecars': 'Muscle cars',
            'deportivos_clasicos': 'Deportivos clásicos',
            'deportivos': 'Deportivos',
            'superdeportivos': 'Superdeportivos',
            'motos': 'Motos'
        };
        document.getElementById('current-cat-name').innerText = catNames[cat] || 'Catálogo';

        this.renderCatalog();
    },

    renderCatalog: function () {
        const container = document.getElementById('vehicles-container');
        container.innerHTML = '';

        const filtered = this.currentCategory === 'all'
            ? allVehicles
            : allVehicles.filter(v => normalizeVehicleCategory(v.category) === this.currentCategory);

        document.getElementById('total-vehicles').innerText = `Mostrando ${filtered.length} modelos exclusivos`;

        filtered.forEach(v => {
            const el = document.createElement('div');
            el.className = 'vehicle-card';
            el.onclick = () => this.previewVehicle(v);

            el.innerHTML = `
                <div class="v-info">
                    <h3>${Utils.escapeHtml(v.name)}</h3>
                    <p>${Utils.formatMoney(v.price)}</p>
                </div>
            `;
            container.appendChild(el);
        });
    },

    previewVehicle: function (v) {
        // Switch to preview mode
        document.getElementById('catalog-view').classList.add('hidden');
        document.getElementById('preview-panel').classList.remove('hidden');

        document.getElementById('preview-name').innerText = v.name;
        document.getElementById('preview-price').innerText = Utils.formatMoney(v.price);

        // Randomize stats for "flavor" since they aren't in DB
        const fills = document.querySelectorAll('.progress-fill');
        fills.forEach(fill => {
            const randomWidth = Math.floor(Math.random() * 40) + 60; // 60-100%
            fill.style.width = randomWidth + '%';
        });

        // Reset payment options
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
    }
};

// Staff Panel Logic
const Staff = {
    pendingDeleteId: null,

    init: function (vehicles) {
        allVehicles = vehicles;
        document.getElementById('staff-ui').classList.remove('hidden');
        document.getElementById('dealership-ui').classList.add('hidden');
        Staff.hideDeleteModal();
        this.renderList();
    },

    renderList: function () {
        const list = document.getElementById('staff-vehicles-list');
        list.innerHTML = '';

        allVehicles.forEach(v => {
            const el = document.createElement('div');
            el.className = 'staff-item';
            el.dataset.vehicleId = String(v.id);
            el.innerHTML = `
                <div class="staff-item-info">
                    <strong>${Utils.escapeHtml(v.name)} (${Utils.escapeHtml(v.model)})</strong>
                    <span>${Utils.formatMoney(v.price)} — ${Utils.escapeHtml(v.category)}</span>
                </div>
                <div class="staff-item-actions">
                    <button type="button" class="btn-icon-staff btn-edit" data-action="edit" aria-label="Editar"><i class="fas fa-edit"></i></button>
                    <button type="button" class="btn-icon-staff btn-delete" data-action="delete" aria-label="Eliminar"><i class="fas fa-trash"></i></button>
                </div>
            `;
            list.appendChild(el);
        });
    },

    editById: function (id) {
        const v = allVehicles.find((x) => Number(x.id) === Number(id));
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
            id: id ? parseInt(id) : null,
            model: model,
            name: name,
            price: parseInt(price),
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
        if (![...sel.options].some(function (o) { return o.value === sel.value; })) {
            sel.value = 'deportivos';
        }
    },

    delete: function (id) {
        const n = Number(id);
        if (!Number.isFinite(n)) return;
        Staff.pendingDeleteId = n;
        const label = document.getElementById('staff-delete-label');
        const v = allVehicles.find((x) => Number(x.id) === n);
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

// Event Listeners for category switching
document.querySelectorAll('#categories-list li').forEach(li => {
    li.addEventListener('click', function () {
        Dealership.setCategory(this.getAttribute('data-cat'), this);
        Dealership.backToCatalog(); // Always reset to catalog when switching cat
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

window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'openDealership') {
        Dealership.init(data.vehicles);
    }

    if (data.action === 'closeUI') {
        Staff.hideDeleteModal();
        document.getElementById('dealership-ui').classList.add('hidden');
        document.getElementById('staff-ui').classList.add('hidden');
    }

    if (data.action === 'forceClose') {
        Staff.hideDeleteModal();
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
            allVehicles = data.vehicles;
            Dealership.renderCatalog();
        }
    }
});

// Close UI on ESC (primero cerrar modal de borrado; nunca depender de window.confirm en NUI)
window.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape') return;
    const delModal = document.getElementById('staff-delete-modal');
    if (delModal && !delModal.classList.contains('hidden')) {
        Staff.hideDeleteModal();
        event.preventDefault();
        return;
    }
    Utils.closeUI();
});
