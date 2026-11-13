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
        const reason = reservation.status === 'cancelled' && reservation.cancellationReason
          ? '<div class="reservation-reason small text-muted mt-1">Motif : ' + escapeHtml(reservation.cancellationReason) + '</div>'
          : '';
        const location = `${escapeHtml(reservation.pickupLocation)} → ${escapeHtml(reservation.returnLocation)}`;
        const row = document.createElement('tr');
        row.innerHTML = `
          <td><div class="fw-semibold">${escapeHtml(client.fullname || 'Client supprimé')}</div><div class="small text-muted">${escapeHtml(client.email || '')}</div></td>
          <td><div class="fw-semibold">${escapeHtml(vehicle.marque || '')} ${escapeHtml(vehicle.modele || 'Véhicule supprimé')}</div><div class="small text-muted">${escapeHtml(vehicle.immatriculation || '')}</div></td>
          <td>${formatDate(reservation.pickupDate)}</td>
          <td>${formatDate(reservation.returnDate)}</td>
          <td>${location}</td>
          <td class="text-nowrap">${formatPrice(reservation.totalPriceMillimes)}</td>
          <td>${status}${reason}</td>
          <td class="text-end">${confirmed
            ? `<button class="btn btn-sm btn-outline-danger btn-pill" type="button" data-action="cancel" data-id="${id}">Annuler la réservation</button>`
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


  function showFeedback(message, type) {
    const feedback = document.getElementById('pageFeedback');
    feedback.className = `alert alert-${type}`;
    feedback.textContent = message;
    feedback.hidden = false;
  }

  function setupCancellation() {
    const dialog = document.getElementById('cancelReservationDialog');
    const form = document.getElementById('cancelReservationForm');
    const reasonInput = document.getElementById('cancelReservationReason');
    const errorBox = document.getElementById('cancelReservationError');
    const back = document.getElementById('cancelReservationBack');
    const submit = document.getElementById('cancelReservationSubmit');
    const progress = document.getElementById('cancelReservationProgress');
    const submitLabel = document.getElementById('cancelReservationSubmitLabel');
    let reservationId;
    let submitting = false;
    let canSubmit = true;

    function showError(message = '') {
      errorBox.textContent = message;
      errorBox.hidden = !message;
    }

    function setSubmitting(pending) {
      submitting = pending;
      back.disabled = pending;
      submit.disabled = pending || !canSubmit;
      reasonInput.readOnly = pending || !canSubmit;
      progress.hidden = !pending;
      submitLabel.textContent = pending ? 'Annulation en cours…' : 'Confirmer l’annulation';
    }

    document.getElementById('reservationRows').addEventListener('click', (event) => {
      const button = event.target.closest('button[data-action="cancel"]');
      if (!button || dialog.open || submitting) return;
      reservationId = button.dataset.id;
      document.getElementById('cancelReservationReference').textContent = reservationId;
      form.reset();
      reasonInput.removeAttribute('aria-invalid');
      showError();
      canSubmit = true;
      setSubmitting(false);
      dialog.showModal();
    });

    reasonInput.addEventListener('input', () => {
      if (reasonInput.hasAttribute('aria-invalid')) {
        reasonInput.removeAttribute('aria-invalid');
        showError();
      }
    });
    back.addEventListener('click', () => dialog.close());
    dialog.addEventListener('cancel', (event) => {
      if (submitting) event.preventDefault();
    });

    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      if (!dialog.open || submitting || !canSubmit) return;

      const reason = reasonInput.value.trim();
      if (!reason || reason.length > reasonInput.maxLength) {
        reasonInput.setAttribute('aria-invalid', 'true');
        showError(reason ? 'Le motif ne doit pas dépasser 500 caractères.' : 'Indiquez un motif d’annulation.');
        reasonInput.focus();
        return;
      }

      reasonInput.removeAttribute('aria-invalid');
      showError();
      setSubmitting(true);
      try {
        const result = await AdminApi.request(
          `/reservations/${encodeURIComponent(reservationId)}/admin-cancel`,
          {
            method: 'POST',
            body: JSON.stringify({ reason }),
            signal: AbortSignal.timeout(15000)
          }
        );
        if (result.success !== true || result.data?._id !== reservationId
          || result.data.status !== 'cancelled') {
          throw new Error('Le serveur n’a pas confirmé l’annulation.');
        }
      } catch (error) {
        if (error.status === 401 || error.status === 403) {
          // The shared session handler has already opened the login overlay.
          dialog.close();
          document.getElementById('loginError').textContent = error.status === 401
            ? 'Votre session a expiré. Veuillez vous reconnecter.'
            : 'Accès refusé. Connectez-vous avec un compte administrateur.';
          document.getElementById('adminEmail').focus();
        } else if (error.status === 409) {
          canSubmit = false;
          showError('Cette réservation est déjà annulée ou ne peut plus être annulée.');
          try {
            await loadReservations();
          } catch {
            showError('Cette réservation ne peut plus être annulée. Utilisez Actualiser pour recharger la liste.');
          }
        } else {
          if (error.status === 404) canSubmit = false;
          if (error.status === 400) {
            reasonInput.setAttribute('aria-invalid', 'true');
            reasonInput.readOnly = false;
            reasonInput.focus();
          }
          showError(error.name === 'TimeoutError'
            ? 'Le serveur ne répond pas. Actualisez la liste avant de réessayer.'
            : error instanceof TypeError
              ? 'Connexion impossible au serveur CarRent. Réessayez.'
              : error.message || 'Impossible d’annuler la réservation.');
        }
        return;
      } finally {
        setSubmitting(false);
      }

      dialog.close();
      try {
        await loadReservations();
        showFeedback('Réservation annulée avec succès.', 'success');
      } catch {
        showFeedback('Réservation annulée. Utilisez Actualiser pour recharger la liste.', 'warning');
      }
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('reservationSearch').addEventListener('input', renderReservations);
    document.getElementById('reservationStatus').addEventListener('change', renderReservations);
    setupCancellation();
    AdminShell.init({ load: loadReservations });
  });
})();
