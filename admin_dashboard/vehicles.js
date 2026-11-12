(() => {
  const vehiclesApi = '/vehicles';
  let vehicles = [];
  let modal;

  const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[char]);

  const formatPrice = (value) => new Intl.NumberFormat('fr-FR', {
    style: 'currency',
    currency: 'EUR'
  }).format(Number(value) || 0);

  function showFeedback(message, type = 'success') {
    const feedback = document.getElementById('pageFeedback');
    feedback.className = `alert alert-${type}`;
    feedback.textContent = message;
    feedback.hidden = false;
  }

  function filteredVehicles() {
    const search = document.getElementById('vehicleSearch').value.trim().toLowerCase();
    const availability = document.getElementById('availabilityFilter').value;
    return vehicles.filter((vehicle) => {
      const text = [
        vehicle.marque,
        vehicle.modele,
        vehicle.immatriculation,
        vehicle.carburant
      ].join(' ').toLowerCase();
      return (!search || text.includes(search))
        && (availability === '' || String(vehicle.disponible) === availability);
    });
  }

  function renderVehicles() {
    const rows = document.getElementById('vehicleRows');
    const list = filteredVehicles();
    rows.replaceChildren();

    if (list.length === 0) {
      rows.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-muted">Aucun véhicule ne correspond aux filtres.</td></tr>';
    } else {
      for (const vehicle of list) {
        const id = escapeHtml(vehicle._id);
        const availability = vehicle.disponible
          ? '<span class="badge-state badge-available">Disponible</span>'
          : '<span class="badge-state badge-unavailable">Indisponible</span>';
        const row = document.createElement('tr');
        row.innerHTML = `
          <td class="fw-semibold">${escapeHtml(vehicle.marque)} ${escapeHtml(vehicle.modele)}</td>
          <td>${escapeHtml(vehicle.immatriculation)}</td>
          <td>${escapeHtml(vehicle.annee)}</td>
          <td>${formatPrice(vehicle.prix)}</td>
          <td>${new Intl.NumberFormat('fr-FR').format(Number(vehicle.kilometrage) || 0)} km</td>
          <td>${escapeHtml(vehicle.carburant)}</td>
          <td>${availability}</td>
          <td class="text-end text-nowrap">
            <button class="btn btn-sm btn-outline-primary btn-pill" type="button" data-action="edit" data-id="${id}" aria-label="Modifier le véhicule">Modifier</button>
            <button class="btn btn-sm btn-outline-danger btn-pill" type="button" data-action="delete" data-id="${id}" aria-label="Supprimer le véhicule">Supprimer</button>
          </td>`;
        rows.append(row);
      }
    }

    document.getElementById('vehicleCount').textContent =
      `${list.length} véhicule${list.length === 1 ? '' : 's'} affiché${list.length === 1 ? '' : 's'}`;
  }

  async function loadVehicles() {
    const result = await AdminApi.request(vehiclesApi);
    if (!Array.isArray(result.data)) {
      throw new Error('La réponse des véhicules est invalide.');
    }
    vehicles = result.data;
    document.getElementById('totalVehicles').textContent = vehicles.length;
    document.getElementById('availableVehicles').textContent =
      vehicles.filter((vehicle) => vehicle.disponible).length;
    document.getElementById('unavailableVehicles').textContent =
      vehicles.filter((vehicle) => !vehicle.disponible).length;
    renderVehicles();
    document.getElementById('pageFeedback').hidden = true;
  }

  function openVehicleForm(vehicle) {
    const form = document.getElementById('vehicleForm');
    form.reset();
    form.dataset.vehicleId = vehicle?._id || '';
    document.getElementById('vehicleFormError').hidden = true;
    document.getElementById('vehicleModalTitle').textContent =
      vehicle ? 'Modifier un véhicule' : 'Ajouter un véhicule';
    document.getElementById('vehicleYear').max =
      String(new Date().getFullYear() + 1);
    if (vehicle) {
      form.elements.marque.value = vehicle.marque;
      form.elements.modele.value = vehicle.modele;
      form.elements.immatriculation.value = vehicle.immatriculation;
      form.elements.annee.value = vehicle.annee;
      form.elements.prix.value = vehicle.prix;
      form.elements.kilometrage.value = vehicle.kilometrage;
      form.elements.carburant.value = vehicle.carburant;
      form.elements.image.value = vehicle.image || '';
      form.elements.disponible.checked = Boolean(vehicle.disponible);
    } else {
      form.elements.disponible.checked = true;
    }
    modal.show();
  }

  async function saveVehicle(event) {
    event.preventDefault();
    const form = event.currentTarget;
    if (!form.reportValidity()) return;

    const button = document.getElementById('saveVehicle');
    const error = document.getElementById('vehicleFormError');
    button.disabled = true;
    error.hidden = true;
    const payload = {
      marque: form.elements.marque.value.trim(),
      modele: form.elements.modele.value.trim(),
      immatriculation: form.elements.immatriculation.value.trim().toUpperCase(),
      annee: Number(form.elements.annee.value),
      prix: Number(form.elements.prix.value),
      kilometrage: Number(form.elements.kilometrage.value),
      carburant: form.elements.carburant.value,
      disponible: form.elements.disponible.checked,
      image: form.elements.image.value.trim()
    };
    const id = form.dataset.vehicleId;

    try {
      const result = await AdminApi.request(
        id ? `${vehiclesApi}/${encodeURIComponent(id)}` : vehiclesApi,
        {
          method: id ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        }
      );
      modal.hide();
      await loadVehicles();
      showFeedback(result.message || 'Véhicule enregistré.');
    } catch (requestError) {
      error.textContent = requestError.message || 'Impossible d’enregistrer le véhicule.';
      error.hidden = false;
    } finally {
      button.disabled = false;
    }
  }

  async function deleteVehicle(vehicle) {
    if (!window.confirm(`Supprimer ${vehicle.marque} ${vehicle.modele} ?`)) return;
    try {
      const result = await AdminApi.request(
        `${vehiclesApi}/${encodeURIComponent(vehicle._id)}`,
        { method: 'DELETE' }
      );
      await loadVehicles();
      showFeedback(result.message || 'Véhicule supprimé.');
    } catch (error) {
      showFeedback(error.message || 'Impossible de supprimer le véhicule.', 'danger');
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    modal = new bootstrap.Modal(document.getElementById('vehicleModal'));
    document.getElementById('addVehicle').addEventListener('click', () => {
      openVehicleForm(null);
    });
    document.getElementById('vehicleForm').addEventListener('submit', saveVehicle);
    document.getElementById('vehicleSearch').addEventListener('input', renderVehicles);
    document.getElementById('availabilityFilter').addEventListener('change', renderVehicles);
    document.getElementById('vehicleRows').addEventListener('click', (event) => {
      const button = event.target.closest('button[data-action]');
      if (!button) return;
      const vehicle = vehicles.find((item) => item._id === button.dataset.id);
      if (!vehicle) return;
      if (button.dataset.action === 'edit') openVehicleForm(vehicle);
      if (button.dataset.action === 'delete') deleteVehicle(vehicle);
    });
    AdminShell.init({ load: loadVehicles });
  });
})();
