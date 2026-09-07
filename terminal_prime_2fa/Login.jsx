import Checkbox from '@/Components/Checkbox';
import InputError from '@/Components/InputError';
import { Head, useForm } from '@inertiajs/react';
import { useState, useEffect, useRef } from 'react';

function getOrCreateDeviceId() {
    try {
        let id = localStorage.getItem('terminal_device_id');
        if (!id) {
            if (typeof crypto !== 'undefined' && crypto.randomUUID) {
                id = crypto.randomUUID().toUpperCase();
            } else {
                id = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
                    const r = (Math.random() * 16) | 0;
                    const v = c === 'x' ? r : (r & 0x3) | 0x8;
                    return v.toString(16).toUpperCase();
                });
            }
            localStorage.setItem('terminal_device_id', id);
        }
        return id;
    } catch (e) {
        return null;
    }
}

function getXsrfToken() {
    try {
        if (typeof document === 'undefined') return '';
        const match = document.cookie.match(new RegExp('(^|;\\s*)XSRF-TOKEN=([^;]+)'));
        return match ? decodeURIComponent(match[2]) : '';
    } catch (e) {
        return '';
    }
}

export default function Login({ status }) {
    const [showPassword, setShowPassword] = useState(false);
    const coordsRef = useRef({ latitude: null, longitude: null });
    const [inactivityNotice, setInactivityNotice] = useState(false);

    // ── 2FA STATE ────────────────────────────────────────────────────────────
    const [show2FAModal, setShow2FAModal] = useState(false);
    const [securityCode, setSecurityCode] = useState('');
    const [countdown, setCountdown] = useState(90);
    const [authError, setAuthError] = useState('');
    const [isVerifying, setIsVerifying] = useState(false);
    const pollTimerRef = useRef(null);
    const countdownTimerRef = useRef(null);

    const { data, setData, post, processing, errors, reset } = useForm({
        email: '',
        password: '',
        remember: false,
        device_id: typeof window !== 'undefined' ? getOrCreateDeviceId() : '',
        latitude: null,
        longitude: null,
    });

    useEffect(() => {
        try {
            const urlParams = new URLSearchParams(window.location.search);
            if (urlParams.get('reason') === 'inactivity' || sessionStorage.getItem('logout_reason') === 'inactivity') {
                setInactivityNotice(true);
                sessionStorage.removeItem('logout_reason');
            }
        } catch (e) {}

        if (typeof window !== 'undefined' && navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    if (pos?.coords) {
                        const lat = pos.coords.latitude;
                        const lon = pos.coords.longitude;
                        coordsRef.current = { latitude: lat, longitude: lon };
                        setData((prev) => ({ ...prev, latitude: lat, longitude: lon }));
                    }
                },
                () => {},
                { enableHighAccuracy: true, timeout: 8000, maximumAge: 60000 }
            );
        }

        return () => {
            if (pollTimerRef.current) clearInterval(pollTimerRef.current);
            if (countdownTimerRef.current) clearInterval(countdownTimerRef.current);
        };
    }, []);

    // ── STEP 1: VERIFY CREDENTIALS & TRIGGER 2FA ──────────────────────────────
    const submit = async (e) => {
        e.preventDefault();
        if (isVerifying || processing || show2FAModal) return;
        setAuthError('');
        setIsVerifying(true);

        const currentDeviceId = getOrCreateDeviceId();
        data.device_id = currentDeviceId;
        if (coordsRef.current.latitude) {
            data.latitude = coordsRef.current.latitude;
            data.longitude = coordsRef.current.longitude;
        }

        try {
            console.log('%c[2FA Step 1] Checking credentials with Laravel...', 'color: #2563eb; font-weight: bold;', { email: data.email });

            // A. Check password with Laravel first (uses /api/check-credentials to avoid CSRF mismatch)
            let checkRes = await fetch('/api/check-credentials', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                },
                body: JSON.stringify({ email: data.email, password: data.password }),
            });

            // Fallback to /check-credentials if /api/check-credentials is 404
            if (checkRes.status === 404) {
                console.log('%c[2FA Step 1] /api/check-credentials returned 404, falling back to /check-credentials...', 'color: #ca8a04;');
                const xsrfToken = getXsrfToken() || document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';
                checkRes = await fetch('/check-credentials', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                        'X-XSRF-TOKEN': xsrfToken,
                        'X-CSRF-TOKEN': xsrfToken,
                    },
                    body: JSON.stringify({ email: data.email, password: data.password }),
                });
            }

            const checkData = await checkRes.json();
            console.log('%c[2FA Step 1] Response received:', 'color: #2563eb;', checkRes.status, checkData);

            if (!checkRes.ok || !checkData.success) {
                console.warn('%c[2FA Step 1 Failed]', 'color: #dc2626; font-weight: bold;', checkData.message);
                setIsVerifying(false);
                setAuthError(checkData.message || 'Invalid email or password.');
                return;
            }

            // B. Admin users skip 2FA entirely — login directly
            if (checkData.role === 'admin' || checkData.requires_2fa === false || checkData.is_admin === true) {
                console.log('%c[2FA] Admin user detected — skipping 2FA, logging in directly.', 'color: #16a34a; font-weight: bold;');
                setIsVerifying(false);
                post(route('login'), {
                    onFinish: () => reset('password'),
                });
                return;
            }

            // C. Password OK! Trigger 2FA Push on the phone
            const employeeId = checkData.employee_id;
            console.log('%c[2FA Step 2] Credentials verified! Dispatching phone notification...', 'color: #9333ea; font-weight: bold;', { employeeId, email: data.email, name: checkData.name });

            const twoFaRes = await fetch('https://exploresuite.lk/mobile-api/api/create_2fa_challenge.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                },
                body: JSON.stringify({
                    employee_id: String(employeeId),
                    email: data.email,
                    website_name: 'Terminal Prime Airport Counter',
                    device_info: navigator.userAgent,
                }),
            });

            const twoFaData = await twoFaRes.json();
            console.log('%c[2FA Step 2] Push dispatch response:', 'color: #9333ea;', twoFaData);

            if (!twoFaData.success) {
                console.error('%c[2FA Step 2 Failed]', 'color: #dc2626; font-weight: bold;', twoFaData.message);
                setIsVerifying(false);
                setAuthError(twoFaData.message || 'Failed to dispatch phone verification.');
                return;
            }

            // D. Open 2FA Popup Modal & Start Polling
            console.log(`%c[2FA Step 3] 2FA Challenge #${twoFaData.challenge_id} created! Security Code: ${twoFaData.security_code}`, 'color: #16a34a; font-weight: bold;');
            setIsVerifying(false);
            setSecurityCode(twoFaData.security_code);
            setCountdown(twoFaData.expires_in || 90);
            setShow2FAModal(true);

            startCountdownAndPolling(twoFaData.challenge_id);

        } catch (err) {
            console.error('%c[2FA Fatal Error]', 'color: #dc2626; font-weight: bold;', err);
            setIsVerifying(false);
            setAuthError(err.message || 'Connection error during authentication. Please retry.');
        }
    };

    // ── STEP 2: POLL 2FA STATUS & FINALIZE INERTIA LOGIN ──────────────────────
    const startCountdownAndPolling = (challengeId) => {
        console.log(`%c[2FA Poller] Started polling for Challenge #${challengeId}...`, 'color: #0284c7;');

        // Countdown interval
        countdownTimerRef.current = setInterval(() => {
            setCountdown((prev) => {
                if (prev <= 1) {
                    console.warn(`%c[2FA Poller] Challenge #${challengeId} expired!`, 'color: #dc2626;');
                    clearInterval(countdownTimerRef.current);
                    close2FAModal();
                    setAuthError('Sign-in request timed out. Please try again.');
                    return 0;
                }
                return prev - 1;
            });
        }, 1000);

        // Fast 750ms polling for instant response upon mobile approval
        pollTimerRef.current = setInterval(async () => {
            try {
                const res = await fetch(`https://exploresuite.lk/mobile-api/api/check_2fa_status.php?challenge_id=${challengeId}`);
                const resData = await res.json();
                console.log(`%c[2FA Polling #${challengeId}] Status:`, resData.status === 'APPROVED' ? 'color: #16a34a; font-weight: bold;' : 'color: #64748b;', resData.status);

                if (resData.status === 'APPROVED') {
                    console.log('%c[2FA Approved! 🎉] Phone verified! Instant login session starting...', 'color: #16a34a; font-weight: bold;');
                    if (pollTimerRef.current) clearInterval(pollTimerRef.current);
                    if (countdownTimerRef.current) clearInterval(countdownTimerRef.current);
                    close2FAModal();
                    post(route('login'), {
                        onFinish: () => reset('password'),
                    });
                } else if (resData.status === 'DECLINED') {
                    console.warn('%c[2FA Declined ❌] Phone rejected the request.', 'color: #dc2626; font-weight: bold;');
                    close2FAModal();
                    setAuthError('Login request was DECLINED on your phone.');
                } else if (resData.status === 'EXPIRED') {
                    console.warn('%c[2FA Expired ⏱️] Challenge has timed out.', 'color: #dc2626; font-weight: bold;');
                    close2FAModal();
                    setAuthError('Sign-in request timed out. Please try again.');
                }
            } catch (e) {
                console.error('[2FA Polling Error]', e);
            }
        }, 750);
    };

    const close2FAModal = () => {
        if (pollTimerRef.current) clearInterval(pollTimerRef.current);
        if (countdownTimerRef.current) clearInterval(countdownTimerRef.current);
        setShow2FAModal(false);
    };

    return (
        <>
            <Head title="Airport Counter Login" />

            <div
                className="min-h-screen flex items-center justify-center bg-cover bg-center px-4"
                style={{
                    backgroundImage:
                        "linear-gradient(rgba(2, 6, 23, 0.68), rgba(2, 6, 23, 0.68)), url('/assets/images/airport-login-bg-1.jpg')",
                }}
            >
                <div className="w-full max-w-md">
                    <div className="bg-white/95 backdrop-blur rounded-2xl shadow-2xl p-8">
                        <div className="text-center mb-7">
                            <div className="mx-auto h-14 w-14 rounded-2xl overflow-hidden mb-3">
                                <img
                                    src="/assets/images/logo.png"
                                    alt="Airport"
                                    className="h-full w-full object-cover"
                                />
                            </div>

                            <h1 className="text-3xl font-bold text-slate-900">
                                TERMINAL PRIME
                            </h1>

                            <p className="text-sm text-slate-500">
                                Airport Counter Login
                            </p>
                        </div>

                        {status && (
                            <div className="mb-4 rounded-lg bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-700">
                                {status}
                            </div>
                        )}

                        {inactivityNotice && (
                            <div className="mb-4 rounded-xl bg-amber-50 border border-amber-200 px-4 py-3 text-xs font-semibold text-amber-800 flex items-center gap-2 shadow-sm">
                                <span className="text-base">⏱️</span>
                                <span>You have been logged out due to 10 minutes of inactivity.</span>
                            </div>
                        )}

                        {authError && (
                            <div className="mb-4 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm font-medium text-red-700">
                                {authError}
                            </div>
                        )}

                        <form onSubmit={submit} className="space-y-5">
                            <div>
                                <label className="block text-sm font-semibold text-slate-700 mb-1">
                                    Email Address
                                </label>

                                <input
                                    id="email"
                                    type="email"
                                    name="email"
                                    value={data.email}
                                    autoComplete="username"
                                    autoFocus
                                    onChange={(e) => setData('email', e.target.value)}
                                    placeholder="counter@airport.lk"
                                    className="w-full rounded-xl border-slate-300 px-4 py-3 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                                />

                                <InputError message={errors.email} className="mt-2" />
                            </div>

                            <div>
                                <label className="block text-sm font-semibold text-slate-700 mb-1">
                                    Password
                                </label>

                                <div className="relative">
                                    <input
                                        id="password"
                                        type={showPassword ? 'text' : 'password'}
                                        name="password"
                                        value={data.password}
                                        autoComplete="current-password"
                                        onChange={(e) => setData('password', e.target.value)}
                                        placeholder="Enter password"
                                        className="w-full rounded-xl border-slate-300 px-4 py-3 pr-20 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                                    />

                                    <button
                                        type="button"
                                        onClick={() => setShowPassword(!showPassword)}
                                        className="absolute right-4 top-3 text-sm font-semibold text-blue-700"
                                    >
                                        {showPassword ? 'Hide' : 'Show'}
                                    </button>
                                </div>

                                <InputError message={errors.password} className="mt-2" />
                            </div>

                            <div className="flex items-center justify-between">
                                <label className="flex items-center">
                                    <Checkbox
                                        name="remember"
                                        checked={data.remember}
                                        onChange={(e) => setData('remember', e.target.checked)}
                                    />
                                    <span className="ms-2 text-sm text-slate-600">
                                        Remember me
                                    </span>
                                </label>
                            </div>

                            <button
                                type="submit"
                                disabled={processing || isVerifying}
                                className="w-full rounded-xl bg-blue-900 px-4 py-3 text-white font-semibold shadow-lg hover:bg-blue-800 active:scale-[0.98] transition disabled:opacity-50"
                            >
                                {isVerifying ? 'Checking...' : processing ? 'Signing in...' : 'Log in with 2FA'}
                            </button>
                        </form>
                    </div>

                    <p className="text-center text-xs text-white/80 mt-4">
                        © {new Date().getFullYear()} Explore Holdings IT Department
                    </p>
                </div>
            </div>

            {/* ── 2FA TAILWIND POPUP MODAL ────────────────────────────────────── */}
            {show2FAModal && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 backdrop-blur-md px-4">
                    <div className="w-full max-w-sm rounded-3xl bg-white p-7 text-center shadow-2xl animate-in fade-in zoom-in duration-200">
                        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-blue-50 text-blue-600 text-3xl">
                            🛡️
                        </div>

                        <h2 className="text-xl font-extrabold text-slate-900">
                            Check Your Phone
                        </h2>

                        <p className="mt-1.5 text-xs text-slate-500 leading-relaxed">
                            A login request was sent to your <strong>Explore Enterprise Suite</strong> mobile app.
                        </p>

                        <div className="my-5 inline-block rounded-2xl border border-amber-200 bg-amber-50 px-6 py-2.5">
                            <span className="block text-[11px] font-bold uppercase tracking-wider text-amber-800">
                                Verification Number
                            </span>
                            <span className="text-3xl font-black tracking-widest text-amber-900">
                                {securityCode}
                            </span>
                        </div>

                        <div className="flex items-center justify-center gap-2 text-xs font-semibold text-slate-500">
                            <div className="h-4 w-4 animate-spin rounded-full border-2 border-slate-300 border-t-blue-600"></div>
                            <span>Waiting for approval... ({countdown}s)</span>
                        </div>

                        <button
                            type="button"
                            onClick={close2FAModal}
                            className="mt-6 w-full rounded-xl border border-slate-300 py-2.5 text-xs font-bold text-slate-600 hover:bg-slate-50 transition"
                        >
                            Cancel
                        </button>
                    </div>
                </div>
            )}
        </>
    );
}
