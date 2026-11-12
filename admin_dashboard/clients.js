(() => {
  const pageSize = 10;
  let page = 1;
  let pages = 0;
  let total = 0;
  let searchTimer;

  const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, character => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[character]);

  const safeImageUrl = value => {
    try {
      if (typeof value !== 'string' || !value.trim()) return '';
      const url = new URL(value, window.location.href);
      return ['http:', 'https:'].includes(url.protocol) ? url.href : '';
    } catch {
      return '';
    }
  };

  function showLogin(message = '') {
    document.getElementById('adminLoginOverlay').hidden = false;
    const error = document.getElementById('loginError');
    error.textContent = message;
    error.hidden = !message;
  }

  function showFeedback(message, type = 'success') {
    const alert = document.getElementById('feedbackAlert');
    alert.className = `alert alert-${type} mx-3 mt-3 mb-0`;
    alert.textContent = message;
    alert.hidden = false;
  }

  function clearFeedback() {
    document.getElementById('feedbackAlert').hidden = true;
  }

  function logoutAdmin(message = '') {
    adminToken = '';
    localStorage.removeItem('carrent_admin_token');
    clientsData = [];
    total = 0;
    pages = 0;
    page = 1;
    updateStats(0, 0, 0, 0);
    renderTable([]);
    updatePagination();
    showLogin(message);
  }

  async function loginAdmin(event) {
    event.preventDefault();
    const button = document.getElementById('loginSubmit');
    const error = document.getElementById('loginError');
    button.disabled = true;
    error.hidden = true;

    try {
      const response = await fetch(`${API_URL}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: document.getElementById('adminEmail').value.trim(),
          password: document.getElementById('adminPassword').value
        })
      });
      const result = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(result.message || 'Connexion impossible.');
      }
      if (result.user.role !== 'admin') {
        throw new Error('Ce compte ne possède pas les droits administrateur.');
      }

      adminToken = result.token;
      localStorage.setItem('carrent_admin_token', adminToken);
      document.getElementById('adminName').textContent = result.user.fullname;
      document.getElementById('adminLoginOverlay').hidden = true;
      document.getElementById('adminPassword').value = '';
      page = 1;
      await loadClients();
    } catch (requestError) {
      error.textContent = requestError.message || 'Erreur de connexion à l’API.';
      error.hidden = false;
    } finally {
      button.disabled = false;
    }
  }

  function updateStats(clients, active, pending, suspended) {
    document.getElementById('stat-total').textContent = clients;
    document.getElementById('stat-active').textContent = active;
    document.getElementById('stat-pending').textContent = pending;
    document.getElementById('stat-suspended').textContent = suspended;
  }

  function updatePagination() {
    const first = total === 0 ? 0 : (page - 1) * pageSize + 1;
    const last = Math.min(page * pageSize, total);
    document.getElementById('footerCountText').textContent =
      `Affichage de ${first} à ${last} sur ${total} client${total === 1 ? '' : 's'}`;
    document.getElementById('pageIndicator').textContent =
      `${pages === 0 ? 0 : page} / ${pages}`;
    document.getElementById('previousPage').disabled = page <= 1;
    document.getElementById('nextPage').disabled = page >= pages;
  }

  async function loadClients() {
    if (!adminToken) {
      showLogin();
      return;
    }

    const params = new URLSearchParams({
      page: String(page),
      limit: String(pageSize),
      search: document.getElementById('searchInput').value.trim(),
      status: document.getElementById('statusFilter').value
    });

    try {
      const response = await fetch(`${API_URL}?${params}`, {
        headers: { Authorization: `Bearer ${adminToken}` }
      });
      if (response.status === 401 || response.status === 403) {
        logoutAdmin('Votre session a expiré. Veuillez vous reconnecter.');
        return;
      }

      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.message || 'Impossible de charger les clients.');
      }

      clientsData = result.data;
      total = result.pagination.total;
      pages = result.pagination.totalPages;
      page = result.pagination.page;
      updateStats(
        result.stats.totalClients,
        result.stats.activeCount,
        result.stats.pendingCount,
        result.stats.suspendedCount
      );
      renderTable(clientsData);
      updatePagination();
      clearFeedback();
    } catch (requestError) {
      showFeedback(requestError.message || 'Erreur lors du chargement des clients.', 'danger');
    }
  }

  function renderTable(list) {
    const tbody = document.getElementById('clientsTableBody');
    tbody.replaceChildren();

    if (list.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="text-center py-5 text-muted">Aucun client trouvé pour ces critères.</td></tr>';
      return;
    }

    for (const client of list) {
      const id = escapeHtml(client._id);
      const fullname = escapeHtml(client.fullname);
      const avatar = safeImageUrl(client.avatar);
      const license = client.driverLicense || {};
      let statusBadge;

      if (client.status === 'active') {
        statusBadge = '<span class="badge-status badge-active"><i class="fa-solid fa-circle-check"></i> Actif</span>';
      } else if (client.status === 'pending_approval') {
        statusBadge = '<span class="badge-status badge-pending"><i class="fa-solid fa-clock"></i> En attente</span>';
      } else {
        statusBadge = '<span class="badge-status badge-suspended"><i class="fa-solid fa-ban"></i> Suspendu</span>';
      }

      const row = document.createElement('tr');
      row.innerHTML = `
        <td><div class="d-flex align-items-center">
          ${avatar
            ? `<img src="${escapeHtml(avatar)}" class="avatar-img me-2" alt="${fullname}">`
            : `<div class="avatar-placeholder me-2">${escapeHtml(fullname.charAt(0) || '?')}</div>`}
          <div><button class="client-profile-link fw-bold" type="button" onclick="openDetailsModal('${id}')">${fullname}</button>
          <div class="text-muted small">ID : ${escapeHtml(client._id.slice(0, 6))}...</div></div>
        </div></td>
        <td><span class="text-dark">${escapeHtml(client.email)}</span></td>
        <td><span class="text-dark">${escapeHtml(client.phone || '-')}</span></td>
        <td>${license.number
          ? `<span class="badge bg-light text-dark border px-2 py-1"><i class="fa-solid fa-id-card text-primary me-1"></i> ${escapeHtml(license.number)}</span>`
          : '<span class="text-muted small">Non renseigné</span>'}</td>
        <td>${statusBadge}</td>
        <td class="text-end"><div class="d-flex justify-content-end gap-1">
          <button class="btn btn-sm btn-outline-primary btn-pill" title="Ouvrir le dossier complet" onclick="openDetailsModal('${id}')"><i class="fa-solid fa-folder-open"></i> Dossier</button>
          ${client.status === 'suspended'
            ? `<button class="btn btn-sm btn-outline-success btn-pill" title="Réactiver" onclick="toggleStatus('${id}', 'active')"><i class="fa-solid fa-check"></i> Réactiver</button>`
            : `<button class="btn btn-sm btn-outline-warning btn-pill" title="Suspendre" onclick="toggleStatus('${id}', 'suspended')"><i class="fa-solid fa-ban"></i> Suspendre</button>`}
          <button class="btn btn-sm btn-outline-danger btn-pill" title="Supprimer" onclick="deleteClient('${id}')"><i class="fa-solid fa-trash"></i></button>
        </div></td>`;
      tbody.appendChild(row);
    }
  }

  function filterTable() {
    page = 1;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(loadClients, 300);
  }

  function changePage(direction) {
    const next = page + direction;
    if (next < 1 || next > pages) return;
    page = next;
    loadClients();
  }

  function formatDate(value) {
    if (!value) return 'Non renseignée';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Non renseignée' : date.toLocaleDateString('fr-FR');
  }

  function formatCurrency(amount, currency) {
    try {
      return new Intl.NumberFormat('fr-FR', {
        style: 'currency',
        currency: currency || 'EUR'
      }).format(Number(amount));
    } catch {
      return `${Number(amount).toFixed(2)} ${currency || 'EUR'}`;
    }
  }

  function renderClientDetails(client) {
    document.getElementById('modalClientName').textContent = `Dossier de ${client.fullname}`;
    document.getElementById('modalFullname').textContent = client.fullname || 'Client';
    document.getElementById('modalEmail').textContent = client.email || 'Non renseigné';
    document.getElementById('modalPhone').textContent = client.phone || 'Non renseigné';
    document.getElementById('modalClientId').textContent = client._id;
    document.getElementById('modalCreatedAt').textContent = formatDate(client.createdAt);
    document.getElementById('modalUpdatedAt').textContent = formatDate(client.updatedAt);
    document.getElementById('modalLicenseNumber').textContent =
      client.driverLicense?.number || 'Non renseigné';
    document.getElementById('modalLicenseDate').textContent =
      formatDate(client.driverLicense?.issuedDate);

    const avatar = document.getElementById('modalAvatar');
    const avatarInitials = document.getElementById('modalAvatarInitials');
    const avatarUrl = safeImageUrl(client.avatar);
    avatar.hidden = !avatarUrl;
    avatarInitials.hidden = Boolean(avatarUrl);
    if (avatarUrl) avatar.src = avatarUrl;
    avatarInitials.textContent = (client.fullname || '?')
      .split(/\s+/)
      .slice(0, 2)
      .map(part => part.charAt(0))
      .join('')
      .toUpperCase();

    const emailBadge = document.getElementById('modalEmailBadge');
    emailBadge.className = client.emailVerified === false ? 'text-danger' : 'text-success';
    emailBadge.innerHTML = client.emailVerified === false
      ? '<i class="fa-solid fa-circle-xmark me-1"></i>Email non vérifié'
      : '<i class="fa-solid fa-circle-check me-1"></i>Email vérifié';

    const photo = document.getElementById('modalLicensePhoto');
    const noPhoto = document.getElementById('modalNoLicensePhoto');
    const photoLink = document.getElementById('modalLicensePhotoLink');
    const photoUrl = safeImageUrl(client.driverLicense?.photoUrl);
    photo.hidden = !photoUrl;
    noPhoto.hidden = Boolean(photoUrl);
    photoLink.hidden = !photoUrl;
    if (photoUrl) {
      photo.src = photoUrl;
      photoLink.href = photoUrl;
    } else {
      photo.removeAttribute('src');
      photoLink.removeAttribute('href');
    }

    const status = client.status;
    const badge = document.getElementById('modalStatusBadge');
    const labels = {
      active: '<span class="badge-status badge-active"><i class="fa-solid fa-circle-check"></i> Actif</span>',
      pending_approval: '<span class="badge-status badge-pending"><i class="fa-solid fa-clock"></i> En attente de validation</span>',
      suspended: '<span class="badge-status badge-suspended"><i class="fa-solid fa-ban"></i> Suspendu</span>'
    };
    badge.innerHTML = labels[status] || escapeHtml(status);
    document.getElementById('modalBtnValidate').hidden = status !== 'pending_approval';
    const statusButton = document.getElementById('modalBtnStatus');
    statusButton.hidden = false;
    statusButton.className = status === 'suspended'
      ? 'btn btn-outline-success btn-pill'
      : 'btn btn-outline-warning btn-pill';
    statusButton.innerHTML = status === 'suspended'
      ? '<i class="fa-solid fa-check me-1"></i>Réactiver le compte'
      : '<i class="fa-solid fa-ban me-1"></i>Suspendre le compte';

    avatar.onerror = () => {
      avatar.hidden = true;
      avatarInitials.hidden = false;
    };
  }

  async function loadClientDetails(id) {
    try {
      const response = await fetch(`${API_URL}/${encodeURIComponent(id)}`, {
        headers: { Authorization: `Bearer ${adminToken}` }
      });
      if (response.status === 401 || response.status === 403) {
        logoutAdmin('Votre session a expiré. Veuillez vous reconnecter.');
        return;
      }
      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.message || 'Impossible de charger le profil complet.');
      }
      if (currentSelectedClient?._id !== id) return;
      currentSelectedClient = result.user;
      renderClientDetails(result.user);
    } catch (requestError) {
      if (currentSelectedClient?._id === id) {
        document.getElementById('modalRentalSummary').textContent =
          requestError.message || 'Impossible de charger le profil complet.';
      }
    }
  }

  function openDetailsModal(id) {
    const client = clientsData.find(item => item._id === id);
    if (!client) return;

    currentSelectedClient = client;
    renderClientDetails(client);
    document.getElementById('modalRentalCount').textContent = '…';
    document.getElementById('modalRentalCompleted').textContent = '…';
    document.getElementById('modalRentalSpend').textContent = '…';
    document.getElementById('modalRentalSummary').textContent = 'Chargement…';
    document.getElementById('modalRentalHistory').className = 'border rounded-3 overflow-hidden p-3 text-muted';
    document.getElementById('modalRentalHistory').textContent = 'Chargement de l’historique…';
    clientModalInstance.show();
    loadClientDetails(id);
    loadClientRentalHistory(id);
  }

  async function loadClientRentalHistory(id) {
    const panel = document.getElementById('modalRentalHistory');
    try {
      const response = await fetch(
        `${API_URL}/${encodeURIComponent(id)}/rentals`,
        { headers: { Authorization: `Bearer ${adminToken}` } }
      );
      if (response.status === 401 || response.status === 403) {
        logoutAdmin('Votre session a expiré. Veuillez vous reconnecter.');
        return;
      }
      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.message || 'Impossible de charger cet historique.');
      }
      if (currentSelectedClient?._id !== id) return;

      const rentals = result.data;
      const completed = rentals.filter(rental => rental.status === 'completed').length;
      const totalsByCurrency = new Map();
      for (const rental of rentals) {
        if (['confirmed', 'ongoing', 'completed'].includes(rental.status)) {
          const currency = rental.currency || 'EUR';
          totalsByCurrency.set(
            currency,
            (totalsByCurrency.get(currency) || 0) + Number(rental.totalPrice || 0)
          );
        }
      }
      document.getElementById('modalRentalCount').textContent = String(rentals.length);
      document.getElementById('modalRentalCompleted').textContent = String(completed);
      document.getElementById('modalRentalSpend').textContent = totalsByCurrency.size
        ? Array.from(totalsByCurrency, ([currency, amount]) => formatCurrency(amount, currency)).join(' · ')
        : formatCurrency(0, 'EUR');
      document.getElementById('modalRentalSummary').textContent =
        `${rentals.length} location${rentals.length === 1 ? '' : 's'} enregistrée${rentals.length === 1 ? '' : 's'}`;

      panel.replaceChildren();
      panel.className = 'border rounded-3 overflow-hidden';
      if (rentals.length === 0) {
        panel.classList.add('p-4', 'text-center', 'text-muted');
        panel.innerHTML = '<i class="fa-solid fa-car-side fa-2x mb-2 d-block"></i>Aucune location enregistrée pour ce client.';
        return;
      }

      const statusLabels = {
        pending: 'En attente',
        confirmed: 'Confirmée',
        ongoing: 'En cours',
        completed: 'Terminée',
        cancelled: 'Annulée'
      };
      const list = document.createElement('div');
      list.className = 'list-group list-group-flush';
      for (const rental of rentals) {
        const item = document.createElement('div');
        item.className = 'list-group-item d-flex flex-wrap justify-content-between align-items-center gap-2 py-3';
        const info = document.createElement('div');
        const vehicle = document.createElement('div');
        vehicle.className = 'fw-bold';
        vehicle.textContent = rental.vehicle?.name || 'Véhicule';
        const dates = document.createElement('div');
        dates.className = 'text-muted small';
        dates.textContent = `${formatDate(rental.startDate)} - ${formatDate(rental.endDate)}`;
        info.append(vehicle, dates);
        const detail = document.createElement('div');
        detail.className = 'text-end';
        const amount = document.createElement('div');
        amount.className = 'fw-bold';
        amount.textContent = formatCurrency(rental.totalPrice, rental.currency);
        const status = document.createElement('span');
        status.className = 'badge text-bg-light';
        status.textContent = statusLabels[rental.status] || rental.status;
        detail.append(amount, status);
        item.append(info, detail);
        list.appendChild(item);
      }
      panel.appendChild(list);
    } catch (requestError) {
      if (currentSelectedClient?._id !== id) return;
      document.getElementById('modalRentalSummary').textContent = 'Historique indisponible';
      panel.className = 'border rounded-3 overflow-hidden p-3 text-danger';
      panel.textContent = requestError.message || 'Erreur lors du chargement de l’historique.';
    }
  }

  async function toggleStatus(id, newStatus) {
    try {
      const response = await fetch(`${API_URL}/${encodeURIComponent(id)}/status`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`
        },
        body: JSON.stringify({ status: newStatus })
      });
      if (response.status === 401 || response.status === 403) {
        logoutAdmin('Votre session a expiré. Veuillez vous reconnecter.');
        return;
      }
      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.message || 'Impossible de modifier le statut du client.');
      }

      const selected = currentSelectedClient?._id === id;
      if (selected) {
        currentSelectedClient = result.user;
        renderClientDetails(result.user);
      }
      await loadClients();
      showFeedback(result.message || 'Le statut du client a été mis à jour.');
    } catch (requestError) {
      showFeedback(requestError.message || 'Erreur lors de la modification du statut.', 'danger');
    }
  }

  function changeStatusFromModal(newStatus) {
    if (!currentSelectedClient) return;
    const id = currentSelectedClient._id;
    toggleStatus(id, newStatus);
  }

  function toggleStatusFromModal() {
    if (!currentSelectedClient) return;
    const nextStatus = currentSelectedClient.status === 'suspended' ? 'active' : 'suspended';
    toggleStatus(currentSelectedClient._id, nextStatus);
  }

  async function deleteClient(id) {
    const client = clientsData.find(item => item._id === id);
    if (!client || !confirm(`Supprimer définitivement le compte de ${client.fullname} ?`)) return;

    try {
      const response = await fetch(`${API_URL}/${encodeURIComponent(id)}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${adminToken}` }
      });
      if (response.status === 401 || response.status === 403) {
        logoutAdmin('Votre session a expiré. Veuillez vous reconnecter.');
        return;
      }
      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.message || 'Impossible de supprimer ce client.');
      }

      if (clientsData.length === 1 && page > 1) page -= 1;
      await loadClients();
      showFeedback(result.message || 'Client supprimé.');
    } catch (requestError) {
      showFeedback(requestError.message || 'Erreur lors de la suppression.', 'danger');
    }
  }

  window.loadClients = loadClients;
  window.logoutAdmin = () => logoutAdmin();
  window.filterTable = filterTable;
  window.changePage = changePage;
  window.openDetailsModal = openDetailsModal;
  window.toggleStatus = toggleStatus;
  window.toggleStatusFromModal = toggleStatusFromModal;
  window.changeStatusFromModal = changeStatusFromModal;
  window.deleteClient = deleteClient;

  document.addEventListener('DOMContentLoaded', () => {
    clientModalInstance = new bootstrap.Modal(document.getElementById('clientModal'));
    document.getElementById('adminLoginForm').addEventListener('submit', loginAdmin);
    if (!adminToken) {
      clientsData = [];
      updateStats(0, 0, 0, 0);
      renderTable([]);
      updatePagination();
      showLogin();
    } else {
      document.getElementById('adminLoginOverlay').hidden = true;
      loadClients();
    }
  });
})();
