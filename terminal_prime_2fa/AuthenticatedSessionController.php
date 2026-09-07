<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;
use Inertia\Response;

class AuthenticatedSessionController extends Controller
{
    /**
     * Display the login view.
     */
    public function create(): Response
    {
        return Inertia::render('Auth/Login', [
            'canResetPassword' => Route::has('password.request'),
            'status' => session('status'),
        ]);
    }

    /**
     * Step 1: Pre-check credentials before triggering 2FA mobile prompt.
     * Called via AJAX by Login.jsx.
     */
    public function checkCredentials(Request $request): JsonResponse
    {
        \Illuminate\Support\Facades\Log::info('[2FA] >>> Pre-check credentials requested', [
            'email' => $request->email,
            'ip'    => $request->ip(),
        ]);

        $request->validate([
            'email'    => 'required|string|email',
            'password' => 'required|string',
        ]);

        // Validate password against database without logging in yet
        if (!Auth::validate($request->only('email', 'password'))) {
            \Illuminate\Support\Facades\Log::warning('[2FA] Invalid credentials entered for: ' . $request->email);
            return response()->json([
                'success' => false,
                'message' => 'These credentials do not match our records.',
            ], 422);
        }

        // Retrieve user to extract employee_id for 2FA push notification
        $user = User::where('email', $request->email)->first();
        
        // Check if admin (bypasses 2FA mobile notification)
        $isAdmin = ($user->role ?? null) === 'admin'
            || ($user->role ?? null) === 'super_admin'
            || ($user->is_admin ?? false) == 1
            || (property_exists($user, 'is_admin') && $user->is_admin)
            || str_contains(strtolower($user->email), 'admin');

        $employeeId = $user->employee_id ?? $user->id;

        \Illuminate\Support\Facades\Log::info('[2FA] Credentials MATCH! User ID: ' . $user->id . ', Employee ID: ' . $employeeId . ', Name: ' . $user->name . ', Is Admin: ' . ($isAdmin ? 'YES' : 'NO'));

        return response()->json([
            'success'      => true,
            'employee_id'  => $employeeId,
            'name'         => $user->name,
            'role'         => $isAdmin ? 'admin' : ($user->role ?? 'user'),
            'requires_2fa' => !$isAdmin,
            'is_admin'     => $isAdmin,
        ]);
    }

    /**
     * Step 2: Handle the final login session.
     * Called by Login.jsx after phone approval is received.
     */
    public function store(LoginRequest $request): RedirectResponse
    {
        \Illuminate\Support\Facades\Log::info('[2FA] >>> Final login session creation for: ' . $request->email);

        $request->authenticate();

        $request->session()->regenerate();

        \Illuminate\Support\Facades\Log::info('[2FA] Session created successfully! Redirecting to dashboard.');

        return redirect()->intended(route('dashboard', absolute: false));
    }

    /**
     * Destroy an authenticated session.
     */
    public function destroy(Request $request): RedirectResponse
    {
        Auth::guard('web')->logout();

        $request->session()->invalidate();

        $request->session()->regenerateToken();

        return redirect('/');
    }
}
