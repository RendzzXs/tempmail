#!/bin/bash
# ==========================================
# 📧 RenMail v2.0 - YOPmail Style (Custom Name)
# Permanen • No Password • Auto Refresh 5s
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

DOMAIN="hackingg.myboc.my.id"
WEB_ROOT="/var/www/$DOMAIN"
MAIL_ROOT="$WEB_ROOT/mail"

echo -e "${CYAN}[1/3] Membuat Folder & File Baru...${NC}"
rm -rf "$MAIL_ROOT"
mkdir -p "$MAIL_ROOT"

# --- BACKEND API PROXY (PHP) ---
cat > "$MAIL_ROOT/api.php" << 'PHPEOF'
<?php
header('Content-Type: application/json');
error_reporting(0); // Biar ga ada HTML error yang ngerusak JSON

$action = $_GET['action'] ?? '';
$base = 'https://api.mail.tm';
$domain = 'yopmail.com'; // Domain yang dipake

// Helper Curl
function req($url, $method = 'GET', $data = null, $token = null) {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    if ($data) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    }
    if ($token) {
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer ' . $token]);
    }
    $res = curl_exec($ch);
    curl_close($ch);
    return json_decode($res, true);
}

// ==========================================
// 1. BUKA EMAIL CUSTOM (LOGIN TANPA PASSWORD)
// ==========================================
if ($action === 'open') {
    $username = trim($_GET['username'] ?? '');
    if (!$username) { echo json_encode(['status'=>false, 'message'=>'Username kosong']); exit; }
    
    // Bersihin karakter aneh
    $username = strtolower(preg_replace('/[^a-z0-9]/', '', $username));
    $address = $username . '@' . $domain;
    $password = 'renmail_' . md5($username); // Password statis khusus sistem
    
    // Coba Login dulu
    $login = req($base . '/token', 'POST', ['address'=>$address, 'password'=>$password]);
    
    if (isset($login['token'])) {
        // Akun udah ada, langsung kasih token
        echo json_encode(['status'=>true, 'email'=>$address, 'token'=>$login['token']]);
    } else {
        // Akun belum ada, daftarin otomatis
        $acc = req($base . '/accounts', 'POST', ['address'=>$address, 'password'=>$password]);
        if (isset($acc['id'])) {
            $login = req($base . '/token', 'POST', ['address'=>$address, 'password'=>$password]);
            if (isset($login['token'])) {
                echo json_encode(['status'=>true, 'email'=>$address, 'token'=>$login['token']]);
            } else {
                echo json_encode(['status'=>false, 'message'=>'Gagal login setelah daftar']);
            }
        } else {
            echo json_encode(['status'=>false, 'message'=>'Username sudah dipakai orang lain atau error API']);
        }
    }
    exit;
}

// ==========================================
// 2. AMBIL INBOX
// ==========================================
if ($action === 'inbox') {
    $token = $_GET['token'] ?? '';
    if (!$token) { echo json_encode(['status'=>false]); exit; }
    
    $msgs = req($base . '/messages', 'GET', null, $token);
    
    $list = [];
    if (isset($msgs['hydra:member'])) {
        foreach ($msgs['hydra:member'] as $m) {
            $list[] = [
                'id' => $m['id'],
                'from' => $m['from']['address'],
                'subject' => $m['subject'],
                'intro' => $m['intro'],
                'date' => date('H:i', strtotime($m['createdAt']))
            ];
        }
    }
    echo json_encode(['status'=>true, 'messages'=>$list]);
    exit;
}

// ==========================================
// 3. BACA PESAN
// ==========================================
if ($action === 'read') {
    $token = $_GET['token'] ?? '';
    $id = $_GET['id'] ?? '';
    if (!$token || !$id) { echo json_encode(['status'=>false]); exit; }
    
    $msg = req($base . '/messages/' . $id, 'GET', null, $token);
    echo json_encode(['status'=>true, 'data'=>$msg]);
    exit;
}

echo json_encode(['status'=>false, 'message'=>'Action invalid']);
PHPEOF

# --- FRONTEND (HTML/CSS/JS) ---
cat > "$MAIL_ROOT/index.php" << 'PHPEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>RenMail - YOP Style</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
<style>
    :root {
        --bg: #070b14;
        --card: #0f1a2e;
        --primary: #6366f1;
        --primary2: #8b5cf6;
        --success: #10b981;
        --danger: #ef4444;
        --text: #f8fafc;
        --text-muted: #94a3b8;
        --border: #1e2a45;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', sans-serif; }
    body {
        background: var(--bg);
        color: var(--text);
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: flex-start;
        padding: 20px;
        background-image: 
            radial-gradient(circle at 10% 20%, rgba(99,102,241,0.15), transparent 40%),
            radial-gradient(circle at 90% 80%, rgba(139,92,246,0.12), transparent 40%);
    }
    .container { width: 100%; max-width: 600px; }
    .header { text-align: center; margin-bottom: 30px; margin-top: 20px; }
    .header h1 { font-size: 2.2em; font-weight: 800; letter-spacing: -1px; }
    .header h1 i { color: var(--primary); margin-right: 8px; }
    .header p { color: var(--text-muted); font-size: 0.95em; margin-top: 5px; }

    .card {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 20px;
        padding: 25px;
        margin-bottom: 20px;
        box-shadow: 0 10px 40px rgba(0,0,0,0.5);
    }

    /* INPUT CUSTOM USERNAME */
    .input-group {
        display: flex;
        align-items: center;
        background: rgba(0,0,0,0.4);
        border: 1px solid var(--primary);
        border-radius: 12px;
        padding: 5px 15px;
        gap: 10px;
        margin-bottom: 15px;
    }
    .input-group i { color: var(--primary); font-size: 1.2em; }
    .input-group input {
        flex: 1;
        background: transparent;
        border: none;
        color: var(--text);
        padding: 15px 0;
        font-size: 1em;
        font-weight: 600;
        outline: none;
        font-family: monospace;
    }
    .input-group input::placeholder { color: var(--text-muted); font-family: 'Inter', sans-serif; font-weight: 400; }
    .domain-text { color: var(--text-muted); font-size: 0.9em; font-weight: 600; }

    .btn-row { display: flex; gap: 10px; }
    .btn {
        flex: 1;
        padding: 15px;
        border: none;
        border-radius: 12px;
        font-weight: 700;
        font-size: 1em;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 10px;
        transition: 0.3s;
        font-family: inherit;
        color: white;
    }
    .btn-primary { background: linear-gradient(135deg, var(--primary), var(--primary2)); box-shadow: 0 4px 15px rgba(99,102,241,0.3); }
    .btn-primary:hover { transform: translateY(-2px); box-shadow: 0 8px 25px rgba(99,102,241,0.5); }
    .btn-success { background: linear-gradient(135deg, #10b981, #059669); }
    .btn-danger { background: linear-gradient(135deg, #ef4444, #dc2626); }

    /* INBOX SECTION */
    #inboxSection { display: none; }
    
    .email-box {
        display: flex;
        align-items: center;
        background: rgba(0,0,0,0.4);
        border: 1px solid var(--success);
        border-radius: 12px;
        padding: 15px 20px;
        gap: 10px;
        margin-bottom: 15px;
    }
    .email-box i { color: var(--success); font-size: 1.2em; }
    .email-text { flex: 1; font-family: monospace; font-size: 1em; font-weight: 600; color: var(--text); word-break: break-all; }
    .btn-icon { background: var(--success); color: white; border: none; padding: 10px 12px; border-radius: 8px; cursor: pointer; font-size: 1em; transition: 0.3s; }
    .btn-icon:hover { background: #059669; }

    .inbox-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px solid var(--border); }
    .inbox-header h3 { font-size: 1.1em; font-weight: 700; display: flex; align-items: center; gap: 8px; }
    .inbox-header h3 i { color: var(--primary); }
    
    .auto-refresh { display: flex; align-items: center; gap: 5px; font-size: 0.75em; color: var(--success); background: rgba(16,185,129,0.1); padding: 5px 10px; border-radius: 20px; border: 1px solid rgba(16,185,129,0.3); }
    .auto-refresh .dot { width: 6px; height: 6px; background: var(--success); border-radius: 50%; animation: pulse 1.5s infinite; }
    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }

    .inbox-list { display: flex; flex-direction: column; gap: 10px; min-height: 100px; }
    .empty-state { text-align: center; padding: 40px 20px; color: var(--text-muted); }
    .empty-state i { font-size: 3em; margin-bottom: 15px; opacity: 0.3; display: block; }
    
    .mail-item { background: rgba(0,0,0,0.3); border: 1px solid var(--border); border-radius: 12px; padding: 15px; cursor: pointer; transition: 0.3s; }
    .mail-item:hover { border-color: var(--primary); background: rgba(99,102,241,0.05); }
    .mail-top { display: flex; justify-content: space-between; margin-bottom: 5px; }
    .mail-from { font-weight: 700; font-size: 0.9em; color: var(--primary); }
    .mail-date { font-size: 0.75em; color: var(--text-muted); }
    .mail-subject { font-weight: 600; font-size: 0.9em; margin-bottom: 5px; }
    .mail-intro { font-size: 0.85em; color: var(--text-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

    /* MODAL */
    .modal { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.8); z-index: 999; align-items: center; justify-content: center; padding: 20px; }
    .modal.active { display: flex; }
    .modal-content { background: var(--card); border: 1px solid var(--border); border-radius: 20px; padding: 25px; width: 100%; max-width: 550px; max-height: 80vh; overflow-y: auto; }
    .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; border-bottom: 1px solid var(--border); padding-bottom: 15px; }
    .modal-header h3 { font-size: 1.2em; font-weight: 800; }
    .modal-close { background: var(--danger); color: white; border: none; width: 35px; height: 35px; border-radius: 50%; cursor: pointer; font-size: 1.2em; display: flex; align-items: center; justify-content: center; }
    .modal-body { font-size: 0.9em; line-height: 1.7; color: var(--text); word-wrap: break-word; }

    .loader { display: inline-block; width: 20px; height: 20px; border: 3px solid rgba(255,255,255,0.3); border-top-color: white; border-radius: 50%; animation: spin 0.8s linear infinite; }
    @keyframes spin { 100% { transform: rotate(360deg); } }

    @media (max-width: 500px) { .header h1 { font-size: 1.8em; } .card { padding: 20px; } .btn { font-size: 0.85em; padding: 12px; } }
</style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-envelope-open-text"></i>RenMail</h1>
            <p>Custom Email • Permanent • Auto Refresh 5s</p>
        </div>

        <!-- LOGIN CARD -->
        <div class="card" id="loginCard">
            <div class="input-group">
                <i class="fas fa-user"></i>
                <input type="text" id="usernameInput" placeholder="Ketik nama email kamu..." onkeypress="if(event.key==='Enter') openInbox()">
                <span class="domain-text">@yopmail.com</span>
            </div>
            <button class="btn btn-primary" onclick="openInbox()" id="btnOpen" style="width:100%;">
                <i class="fas fa-sign-in-alt"></i> Buka Inbox
            </button>
        </div>

        <!-- INBOX CARD -->
        <div class="card" id="inboxSection">
            <div class="email-box">
                <i class="fas fa-check-circle"></i>
                <span class="email-text" id="emailDisplay"></span>
                <button class="btn-icon" onclick="copyEmail()" title="Copy"><i class="fas fa-copy"></i></button>
            </div>
            
            <div style="display:flex;gap:10px;margin-bottom:20px;">
                <button class="btn btn-danger" onclick="logout()" style="flex:0.4;padding:12px;font-size:0.9em;"><i class="fas fa-sign-out-alt"></i> Ganti Email</button>
                <button class="btn btn-success" onclick="checkInbox(true)" style="flex:1;padding:12px;font-size:0.9em;"><i class="fas fa-sync-alt"></i> Refresh Manual</button>
            </div>

            <div class="inbox-header">
                <h3><i class="fas fa-inbox"></i> Inbox</h3>
                <div class="auto-refresh" id="autoBadge"><div class="dot"></div> Auto Refresh</div>
            </div>
            <div class="inbox-list" id="inboxList">
                <div class="empty-state"><i class="fas fa-envelope"></i><p>Belum ada pesan masuk</p></div>
            </div>
        </div>
    </div>

    <!-- MODAL BACA PESAN -->
    <div class="modal" id="readModal">
        <div class="modal-content">
            <div class="modal-header">
                <h3 id="mailTitle">Baca Pesan</h3>
                <button class="modal-close" onclick="closeModal()"><i class="fas fa-times"></i></button>
            </div>
            <div class="modal-body" id="mailBody"></div>
        </div>
    </div>

<script>
let currentEmail = '';
let currentToken = '';
let refreshInterval = null;

// ============== BUKA INBOX (CUSTOM USERNAME) ==============
async function openInbox() {
    const username = document.getElementById('usernameInput').value.trim();
    if (!username) return alert('Ketik nama email dulu!');

    const btn = document.getElementById('btnOpen');
    btn.innerHTML = '<div class="loader"></div> Menghubungkan...';
    btn.disabled = true;

    try {
        const res = await fetch('api.php?action=open&username=' + encodeURIComponent(username));
        const data = await res.json();
        
        if (data.status) {
            currentEmail = data.email;
            currentToken = data.token;
            
            // Simpan di localstorage biar permanen (bisa auto-login)
            localStorage.setItem('renmail_email', currentEmail);
            localStorage.setItem('renmail_token', currentToken);

            // Tampilkan Inbox
            document.getElementById('loginCard').style.display = 'none';
            document.getElementById('inboxSection').style.display = 'block';
            document.getElementById('emailDisplay').textContent = currentEmail;
            document.getElementById('inboxList').innerHTML = '<div class="empty-state"><i class="fas fa-hourglass-half"></i><p>Menunggu pesan...</p></div>';
            
            startAutoRefresh();
        } else {
            alert('Gagal: ' + data.message);
        }
    } catch (e) {
        alert('Error: ' + e.message);
    }
    
    btn.innerHTML = '<i class="fas fa-sign-in-alt"></i> Buka Inbox';
    btn.disabled = false;
}

// ============== LOGOUT / GANTI EMAIL ==============
function logout() {
    localStorage.removeItem('renmail_email');
    localStorage.removeItem('renmail_token');
    currentEmail = '';
    currentToken = '';
    if (refreshInterval) clearInterval(refreshInterval);
    
    document.getElementById('inboxSection').style.display = 'none';
    document.getElementById('loginCard').style.display = 'block';
    document.getElementById('usernameInput').value = '';
}

// ============== COPY EMAIL ==============
function copyEmail() {
    if (!currentEmail) return;
    navigator.clipboard.writeText(currentEmail).then(() => {
        const btn = event.target.closest('button');
        const originalHTML = btn.innerHTML;
        btn.innerHTML = '<i class="fas fa-check"></i>';
        setTimeout(() => btn.innerHTML = originalHTML, 1500);
    });
}

// ============== CHECK INBOX ==============
async function checkInbox(showAlert = false) {
    if (!currentToken) return;
    const list = document.getElementById('inboxList');
    if (showAlert) list.innerHTML = '<div class="empty-state"><div class="loader"></div></div>';
    
    try {
        const res = await fetch('api.php?action=inbox&token=' + currentToken);
        const data = await res.json();
        
        if (data.status && data.messages.length > 0) {
            list.innerHTML = data.messages.map(m => `
                <div class="mail-item" onclick="readMail('${m.id}')">
                    <div class="mail-top">
                        <div class="mail-from"><i class="fas fa-user-circle"></i> ${m.from}</div>
                        <div class="mail-date"><i class="fas fa-clock"></i> ${m.date}</div>
                    </div>
                    <div class="mail-subject">${m.subject}</div>
                    <div class="mail-intro">${m.intro}</div>
                </div>
            `).join('');
        } else {
            list.innerHTML = '<div class="empty-state"><i class="fas fa-envelope"></i><p>Belum ada pesan masuk</p><p style="font-size:0.8em;margin-top:5px;">Auto refresh setiap 5 detik...</p></div>';
        }
    } catch (e) {
        if (showAlert) list.innerHTML = '<div class="empty-state"><i class="fas fa-exclamation-triangle"></i><p>Gagal load inbox</p></div>';
    }
}

// ============== READ MAIL ==============
async function readMail(id) {
    const modal = document.getElementById('readModal');
    const body = document.getElementById('mailBody');
    const title = document.getElementById('mailTitle');
    
    modal.classList.add('active');
    title.textContent = 'Loading...';
    body.innerHTML = '<div style="text-align:center;padding:20px;"><div class="loader"></div></div>';
    
    try {
        const res = await fetch(`api.php?action=read&token=${currentToken}&id=${id}`);
        const data = await res.json();
        if (data.status) {
            title.textContent = data.data.subject || 'No Subject';
            let content = data.data.text || '';
            if (data.data.html && data.data.html.length > 0) content = data.data.html.join(' ');
            
            // Bersihin script jahat
            content = content.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
            
            body.innerHTML = `
                <p style="margin-bottom:15px;font-size:0.85em;color:var(--text-muted);">
                    <strong>From:</strong> ${data.data.from.address}<br>
                    <strong>Date:</strong> ${new Date(data.data.createdAt).toLocaleString('id-ID')}
                </p>
                <div style="background:rgba(0,0,0,0.3);padding:15px;border-radius:10px;font-size:0.9em;">
                    ${content || '(Pesan kosong)'}
                </div>
            `;
        } else {
            title.textContent = 'Error';
            body.innerHTML = '<p>Gagal load pesan</p>';
        }
    } catch (e) {
        title.textContent = 'Error';
        body.innerHTML = '<p>' + e.message + '</p>';
    }
}

function closeModal() { document.getElementById('readModal').classList.remove('active'); }
document.getElementById('readModal').addEventListener('click', (e) => { if (e.target.id === 'readModal') closeModal(); });

// ============== AUTO REFRESH 5s ==============
function startAutoRefresh() {
    if (refreshInterval) clearInterval(refreshInterval);
    refreshInterval = setInterval(() => {
        if (currentToken) checkInbox(false);
    }, 5000);
}

// ============== AUTO LOGIN (KALAU UDAH PERNAH BUKA) ==============
window.addEventListener('load', () => {
    const savedEmail = localStorage.getItem('renmail_email');
    const savedToken = localStorage.getItem('renmail_token');
    if (savedEmail && savedToken) {
        currentEmail = savedEmail;
        currentToken = savedToken;
        document.getElementById('loginCard').style.display = 'none';
        document.getElementById('inboxSection').style.display = 'block';
        document.getElementById('emailDisplay').textContent = currentEmail;
        checkInbox(false);
        startAutoRefresh();
    }
});
</script>
</body>
</html>
PHPEOF

echo -e "${CYAN}[2/3] Setting Permission...${NC}"
chown -R www-data:www-data "$MAIL_ROOT"
chmod -R 755 "$MAIL_ROOT"

echo -e "${CYAN}[3/3] Testing API...${NC}"
TEST_RESULT=$(curl -s "https://$DOMAIN/mail/api.php?action=open&username=testadmin")
echo -e "${GREEN}✅ Test API: ${TEST_RESULT:0:100}...${NC}"

clear
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ RENMAIL v2.0 (YOP STYLE) BERHASIL!         ║${NC}"
echo -e "${GREEN}║  📧 Custom Name • Permanent • Auto Refresh     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 URL TempMail:${NC} https://$DOMAIN/mail/"
echo ""
echo -e "${YELLOW}💡 FITUR BARU:${NC}"
echo -e "   • Input Nama Sendiri (kayak YOPmail)"
echo -e "   • Permanen selama nama belum dipake orang lain"
echo -e "   • LocalStorage (auto-login besok-besok)"
echo -e "   • Ganti Email 1-click (tombol merah)"
echo -e "   • Auto refresh 5s + dot hijau"
echo ""
echo -e "${GREEN}🚀 Buka di browser!${NC}"
