// Data Cache
let onlinePlayers = [];
let premiumNumbers = [];

// DOM Elements
const wrapper = document.querySelector('.pta-wrapper');
const navItems = document.querySelectorAll('.nav-item');
const tabPanes = document.querySelectorAll('.tab-pane');
const closeBtn = document.getElementById('close-panel-btn');

// Lists and empty states
const onlineList = document.getElementById('online-players-list');
const onlineEmpty = document.getElementById('online-empty');
const premiumList = document.getElementById('premium-numbers-list');
const premiumEmpty = document.getElementById('premium-empty');

// Search Inputs
const searchOnlineInput = document.getElementById('search-online');
const searchPremiumInput = document.getElementById('search-premium');

// Form Elements
const assignForm = document.getElementById('assign-form');
const assignTargetInput = document.getElementById('assign-target');
const assignPhoneInput = document.getElementById('assign-phone');
const assignExpiryInput = document.getElementById('assign-expiry');
const resetFormBtn = document.getElementById('reset-form-btn');

// Toast Elements
const toastBanner = document.getElementById('toast-notification');
const toastIcon = document.getElementById('toast-icon');
const toastMessage = document.getElementById('toast-message');
let toastTimeout = null;

// ==========================================
// API Interaction Helper
// ==========================================
function post(endpoint, data = {}) {
    const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'custom_mob';
    fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data)
    }).catch(error => {
        console.error(`[PTA UI] Error posting to ${endpoint}:`, error);
    });
}

// ==========================================
// Toast Notification System
// ==========================================
function showToast(message, type = 'success') {
    if (toastTimeout) {
        clearTimeout(toastTimeout);
    }
    
    toastMessage.textContent = message;
    
    // Set type styling
    toastBanner.className = 'toast-banner';
    toastBanner.classList.add(type);
    
    if (type === 'success') {
        toastIcon.className = 'fa-solid fa-circle-check';
    } else if (type === 'error') {
        toastIcon.className = 'fa-solid fa-circle-exclamation';
    } else {
        toastIcon.className = 'fa-solid fa-circle-info';
    }
    
    // Display banner
    toastBanner.classList.remove('hidden');
    
    toastTimeout = setTimeout(() => {
        toastBanner.classList.add('hidden');
    }, 4500);
}

// ==========================================
// Navigation & Tab Management
// ==========================================
function switchTab(tabId) {
    // Update sidebar navigation active classes
    navItems.forEach(btn => {
        if (btn.getAttribute('data-tab') === tabId) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    // Update visibility of content sections
    tabPanes.forEach(pane => {
        if (pane.id === tabId) {
            pane.classList.add('active');
        } else {
            pane.classList.remove('active');
        }
    });

    // Trigger tab-specific fetches
    if (tabId === 'online-players') {
        fetchOnlinePlayers();
    } else if (tabId === 'active-premium') {
        fetchPremiumNumbers();
    }
}

// Attach navigation click handlers
navItems.forEach(btn => {
    btn.addEventListener('click', () => {
        switchTab(btn.getAttribute('data-tab'));
    });
});

// ==========================================
// Render Functions
// ==========================================
function renderOnlinePlayers() {
    onlineList.innerHTML = '';
    const query = searchOnlineInput.value.toLowerCase().trim();
    
    const filtered = onlinePlayers.filter(player => {
        return (
            player.name.toLowerCase().includes(query) ||
            player.citizenid.toLowerCase().includes(query) ||
            player.id.toString().includes(query) ||
            player.phone.includes(query) ||
            (player.customNumber && player.customNumber.includes(query))
        );
    });

    if (filtered.length === 0) {
        onlineEmpty.classList.remove('hidden');
    } else {
        onlineEmpty.classList.add('hidden');
        filtered.forEach(player => {
            const tr = document.createElement('tr');
            
            // Build Status Badge
            const statusBadge = player.isPremium 
                ? `<span class="badge badge-premium"><i class="fa-solid fa-star"></i> Premium (${player.customNumber})</span>`
                : `<span class="badge badge-standard">Standard</span>`;

            // Build actions buttons
            let actionButtons = '';
            if (player.isPremium) {
                actionButtons = `
                    <button class="btn btn-secondary btn-action-assign" data-id="${player.id}">
                        <i class="fa-solid fa-pen"></i> Edit
                    </button>
                    <button class="btn btn-action-revoke" data-citizenid="${player.citizenid}">
                        <i class="fa-solid fa-ban"></i> Revoke
                    </button>
                `;
            } else {
                actionButtons = `
                    <button class="btn btn-action-assign" data-id="${player.id}">
                        <i class="fa-solid fa-star"></i> Make Premium
                    </button>
                `;
            }

            tr.innerHTML = `
                <td><strong>${player.id}</strong></td>
                <td>${player.name}</td>
                <td><code>${player.citizenid}</code></td>
                <td>${player.phone}</td>
                <td>${statusBadge}</td>
                <td style="text-align: right;">
                    <div style="display: flex; gap: 8px; justify-content: flex-end;">
                        ${actionButtons}
                    </div>
                </td>
            `;

            // Bind Event Listeners
            const assignBtn = tr.querySelector('.btn-action-assign');
            if (assignBtn) {
                assignBtn.addEventListener('click', () => {
                    assignTargetInput.value = player.id;
                    switchTab('assign-number');
                    assignPhoneInput.focus();
                });
            }

            const revokeBtn = tr.querySelector('.btn-action-revoke');
            if (revokeBtn) {
                revokeBtn.addEventListener('click', () => {
                    revokePremium(player.citizenid);
                });
            }

            onlineList.appendChild(tr);
        });
    }
}

function renderPremiumNumbers() {
    premiumList.innerHTML = '';
    const query = searchPremiumInput.value.toLowerCase().trim();

    const filtered = premiumNumbers.filter(entry => {
        return (
            entry.name.toLowerCase().includes(query) ||
            entry.citizenid.toLowerCase().includes(query) ||
            entry.customNumber.includes(query) ||
            entry.originalNumber.includes(query)
        );
    });

    if (filtered.length === 0) {
        premiumEmpty.classList.remove('hidden');
    } else {
        premiumEmpty.classList.add('hidden');
        filtered.forEach(entry => {
            const tr = document.createElement('tr');
            
            // Format Expiry Date
            let formattedDate = 'N/A';
            if (entry.expiry) {
                const dateObj = new Date(entry.expiry);
                formattedDate = dateObj.toLocaleDateString() + ' ' + dateObj.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }

            tr.innerHTML = `
                <td>${entry.name}</td>
                <td><code>${entry.citizenid}</code></td>
                <td><strong style="color: #a78bfa;">${entry.customNumber}</strong></td>
                <td>${entry.originalNumber}</td>
                <td><span style="color: #fbbf24;"><i class="fa-solid fa-clock-rotate-left"></i> ${formattedDate}</span></td>
                <td style="text-align: right;">
                    <button class="btn btn-action-revoke" data-citizenid="${entry.citizenid}">
                        <i class="fa-solid fa-trash-can"></i> Revoke
                    </button>
                </td>
            `;

            // Bind Event
            tr.querySelector('.btn-action-revoke').addEventListener('click', () => {
                revokePremium(entry.citizenid);
            });

            premiumList.appendChild(tr);
        });
    }
}

// ==========================================
// Actions & API Call Wrappers
// ==========================================
function fetchOnlinePlayers() {
    post('getOnlinePlayers');
}

function fetchPremiumNumbers() {
    post('getPremiumNumbers');
}

function revokePremium(citizenid) {
    post('revokePremiumNumber', { citizenid: citizenid });
}

// Close UI Handler
function closeUI() {
    post('closeUI');
    wrapper.style.display = 'none';
}

// ==========================================
// Event Listeners
// ==========================================
closeBtn.addEventListener('click', closeUI);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeUI();
    }
});

// Live Search Filters
searchOnlineInput.addEventListener('input', renderOnlinePlayers);
searchPremiumInput.addEventListener('input', renderPremiumNumbers);

// Reset Assignment Form
resetFormBtn.addEventListener('click', () => {
    assignForm.reset();
    showToast('Form cleared.', 'primary');
});

// Submit Assignment Form
assignForm.addEventListener('submit', (e) => {
    e.preventDefault();

    const target = assignTargetInput.value.trim();
    const customNumber = assignPhoneInput.value.trim();
    const expiryDays = parseInt(assignExpiryInput.value.trim(), 10);

    if (!target || !customNumber) {
        showToast('Please fill out all required fields.', 'error');
        return;
    }

    if (isNaN(expiryDays) || expiryDays <= 0) {
        showToast('Expiry duration must be at least 1 day.', 'error');
        return;
    }

    // Submit request to client callback
    post('assignPremiumNumber', {
        target: target,
        customNumber: customNumber,
        expiryDays: expiryDays
    });
});

// Listen for message from FiveM client
window.addEventListener('message', (event) => {
    const item = event.data;
    if (item.action === 'open') {
        wrapper.style.display = 'flex';
        // Reset form and defaults
        assignForm.reset();
        searchOnlineInput.value = '';
        searchPremiumInput.value = '';
        
        // Start on online players list by default
        switchTab('online-players');
    } else if (item.action === 'close') {
        wrapper.style.display = 'none';
    } else if (item.action === 'setOnlinePlayers') {
        onlinePlayers = Array.isArray(item.players) ? item.players : [];
        renderOnlinePlayers();
    } else if (item.action === 'setPremiumNumbers') {
        premiumNumbers = Array.isArray(item.premiumList) ? item.premiumList : [];
        renderPremiumNumbers();
    } else if (item.action === 'actionResult') {
        showToast(item.message, item.success ? 'success' : 'error');
        if (item.success) {
            if (item.type === 'assign') {
                assignForm.reset();
                switchTab('active-premium');
            } else if (item.type === 'revoke') {
                if (document.getElementById('online-players').classList.contains('active')) {
                    fetchOnlinePlayers();
                } else {
                    fetchPremiumNumbers();
                }
            }
        }
    }
});

