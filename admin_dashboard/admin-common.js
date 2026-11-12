(() => {
  const apiBase = 'http://localhost:5000/api';
  const tokenKey = 'carrent_admin_token';

  async function parseResponse(response) {
    try {
      return await response.json();
    } catch {
      throw new Error('Réponse invalide reçue du serveur.');
    }
  }

  async function request(path, options = {}) {
    const headers = new Headers(options.headers || {});
    const token = localStorage.getItem(tokenKey);
    if (token) headers.set('Authorization', `Bearer ${token}`);
    if (options.body && !(options.body instanceof FormData)) {
      headers.set('Content-Type', 'application/json');
    }

    const response = await fetch(`${apiBase}${path}`, {
      ...options,
      headers
    });
    const data = await parseResponse(response);
    if (response.status === 401 || response.status === 403) {
      localStorage.removeItem(tokenKey);
      window.dispatchEvent(new CustomEvent('carrent-admin-session-expired'));
    }
    if (!response.ok || data.success === false) {
      throw new Error(data.message || 'La requête a échoué.');
    }
    return data;
  }

  async function login(email, password) {
    const response = await fetch(`${apiBase}/users/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    const data = await parseResponse(response);
    if (!response.ok || !data.success) {
      throw new Error(data.message || 'Connexion impossible.');
    }
    if (data.user?.role !== 'admin') {
      throw new Error('Ce compte ne possède pas les droits administrateur.');
    }
    localStorage.setItem(tokenKey, data.token);
    return data.user;
  }

  window.AdminApi = {
    request,
    login,
    getToken: () => localStorage.getItem(tokenKey)
  };

  window.AdminShell = {
    init({ load }) {
      const overlay = document.getElementById('adminLoginOverlay');
      const loginForm = document.getElementById('adminLoginForm');
      const loginError = document.getElementById('loginError');
      const loginButton = document.getElementById('loginSubmit');
      const feedback = document.getElementById('pageFeedback');
      const adminName = document.getElementById('adminName');
      const showLogin = (message = '') => {
        overlay.hidden = false;
        loginError.textContent = message;
        loginError.hidden = !message;
      };

      const showFeedback = (message, type = 'danger') => {
        feedback.className = `alert alert-${type}`;
        feedback.textContent = message;
        feedback.hidden = false;
      };

      const loadPage = async () => {
        try {
          await load();
        } catch (error) {
          showFeedback(error.message || 'Impossible de charger les données.');
        }
      };

      window.addEventListener('carrent-admin-session-expired', () => {
        showLogin('Votre session a expiré. Veuillez vous reconnecter.');
      });

      loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        loginButton.disabled = true;
        loginError.hidden = true;
        try {
          const user = await login(
            document.getElementById('adminEmail').value.trim(),
            document.getElementById('adminPassword').value
          );
          adminName.textContent = user.fullname;
          document.getElementById('adminPassword').value = '';
          overlay.hidden = true;
          await loadPage();
        } catch (error) {
          loginError.textContent = error.message || 'Erreur de connexion.';
          loginError.hidden = false;
        } finally {
          loginButton.disabled = false;
        }
      });

      document.getElementById('logoutAdmin').addEventListener('click', () => {
        localStorage.removeItem(tokenKey);
        window.location.reload();
      });
      document.getElementById('refreshPage').addEventListener('click', loadPage);

      if (!AdminApi.getToken()) {
        showLogin();
        return;
      }

      request('/users/profile')
        .then((result) => {
          if (result.user?.role !== 'admin') {
            localStorage.removeItem(tokenKey);
            showLogin('Ce compte ne possède pas les droits administrateur.');
            return;
          }
          adminName.textContent = result.user.fullname;
          overlay.hidden = true;
          return loadPage();
        })
        .catch((error) => {
          if (AdminApi.getToken()) showLogin(error.message);
        });
    }
  };
})();
