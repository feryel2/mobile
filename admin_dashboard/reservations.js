(() => {
  let reservations = [];

  const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[char]);

  function formatDate(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime())
      ? '—'
      : new Intl.DateTimeFormat('fr-FR', { timeZone: 'UTC' }).format(date);
  }

  function formatPrice(millimes) {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'EUR'
    }).format((Number(millimes) || 0) / 1000);
  }

  function filteredReservations() {
    const search = document.getElementById('reservationSearch').value.trim().toLowerCase();
    const status = document.getElementById('reservationStatus').value;
    return reservations.filter((reservation) => {
      const client = reservation.clientId || {};
      const vehicle = reservation.vehicleId || {};
      const text = [
        client.fullname,
        client.email,
        vehicle.marque,
        vehicle.modele,
        vehicle.immatriculation,
        reservation.pickupLocation,
        reservation.returnLocation
      ].join(' ').toLowerCase();
      return (!search || text.includes(search))
        && (!status || reservation.status === status);
    });
  }

  function renderReservations() {
    const rows = document.getElementById('reservationRows');
    const list = filteredReservations();
    rows.replaceChildren();

    if (list.length === 0) {
      rows.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-muted">Aucune réservation ne correspond aux filtres.</td></tr>';
    } else {
      for (const reservation of list) {
        const client = reservation.clientId || {};
        const vehicle = reservation.vehicleId || {};
        const id = escapeHtml(reservation._id);
        const confirmed = reservation.status === 'confirmed';
        const status = confirmed
          ? '<span class="badge-state badge-confirmed">Confirmée</span>'
          : '<span class="badge-state badge-cancelled">Annulée</span>';
        const location = `${escapeHtml(reservation.pickupLocation)} → ${escapeHtml(reservation.returnLocation)}`;
        const row = document.createElement('tr');
        row.innerHTML = `
          <td><div class="fw-semibold">${escapeHtml(client.fullname || 'Client supprimé')}</div><div class="small text-muted">${escapeHtml(client.email || '')}</div></td>
          <td><div class="fw-semibold">${escapeHtml(vehicle.marque || '')} ${escapeHtml(vehicle.modele || 'Véhicule supprimé')}</div><div class="small text-muted">${escapeHtml(vehicle.immatriculation || '')}</div></td>
          <td>${formatDate(reservation.pickupDate)}</td>
          <td>${formatDate(reservation.returnDate)}</td>
          <td>${location}</td>
          <td class="text-nowrap">${formatPrice(reservation.totalPriceMillimes)}</td>
          <td>${status}</td>
          <td class="text-end">${confirmed
            ? `<button class="btn btn-sm btn-outline-danger btn-pill" type="button" data-action="cancel" data-id="${id}">Annuler</button>`
            : '<span class="text-muted">—</span>'}</td>`;
        rows.append(row);
      }
    }

    document.getElementById('reservationCount').textContent =
      `${list.length} réservation${list.length === 1 ? '' : 's'} affichée${list.length === 1 ? '' : 's'}`;
  }

  async function loadReservations() {
    const result = await AdminApi.request('/reservations/admin');
    if (!Array.isArray(result.data)) {
      throw new Error('La réponse des réservations est invalide.');
    }
    reservations = result.data;
    document.getElementById('totalReservations').textContent = reservations.length;
    document.getElementById('confirmedReservations').textContent =
      reservations.filter((item) => item.status === 'confirmed').length;
    document.getElementById('cancelledReservations').textContent =
      reservations.filter((item) => item.status === 'cancelled').length;
    renderReservations();
    document.getElementById('pageFeedback').hidden = true;
  }

  async function cancelReservation(id) {
    if (!window.confirm('Annuler cette réservation confirmée ?')) return;
    try {
      const result = await AdminApi.request(
        `/reservations/${encodeURIComponent(id)}/cancel`,
        { method: 'POST' }
      );
      await loadReservations();
      const feedback = document.getElementById('pageFeedback');
      feedback.className = 'alert alert-success';
      feedback.textContent = result.message || 'Réservation annulée.';
      feedback.hidden = false;
    } catch (error) {
      const feedback = document.getElementById('pageFeedback');
      feedback.className = 'alert alert-danger';
      feedback.textContent = error.message || 'Impossible d’annuler la réservation.';
      feedback.hidden = false;
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('reservationSearch').addEventListener('input', renderReservations);
    document.getElementById('reservationStatus').addEventListener('change', renderReservations);
    document.getElementById('reservationRows').addEventListener('click', (event) => {
      const button = event.target.closest('button[data-action="cancel"]');
      if (button) cancelReservation(button.dataset.id);
    });
    AdminShell.init({ load: loadReservations });
  });
})();
