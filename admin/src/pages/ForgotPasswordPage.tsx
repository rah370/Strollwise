import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import {
  ApiError,
  checkApiHealth,
  forgotPassword,
  isLocalApiUrl,
  resetPassword,
  unreachableApiMessage,
} from '../api/client'
import { BrandLogo } from '../components/BrandLogo'
import { Button } from '../components/Button'
import { assetUrl } from '../lib/assetUrl'
import { colors } from '../theme/colors'

export function ForgotPasswordPage() {
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const [email, setEmail] = useState(() => params.get('email')?.trim() ?? '')
  const [code, setCode] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [codeStep, setCodeStep] = useState(false)
  const [hint, setHint] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [apiOk, setApiOk] = useState<boolean | null>(null)

  useEffect(() => {
    checkApiHealth().then(setApiOk)
  }, [])

  async function requestCode(e?: FormEvent) {
    e?.preventDefault()
    if (!email.trim() || !email.includes('@')) {
      setError('Enter the email for your admin account.')
      return
    }
    setLoading(true)
    setError('')
    try {
      const result = await forgotPassword(email.trim().toLowerCase())
      const echoed = result.reset_code?.trim()
      setCodeStep(true)
      if (echoed) {
        setCode(echoed)
        setHint(
          'Mail is not configured on this server, so your reset code is shown here. It expires in 15 minutes.',
        )
      } else {
        setHint(
          result.message ||
            'If that email is registered, we sent a 6-digit code. It expires in 15 minutes.',
        )
      }
    } catch (err) {
      if (err instanceof ApiError) setError(err.message)
      else if (err instanceof TypeError) setError(unreachableApiMessage())
      else setError(err instanceof Error ? err.message : 'Could not send a reset code.')
    } finally {
      setLoading(false)
    }
  }

  async function submitNewPassword(e: FormEvent) {
    e.preventDefault()
    if (code.trim().length < 6) {
      setError('Enter the 6-digit reset code.')
      return
    }
    if (password.length < 8) {
      setError('New password must be at least 8 characters.')
      return
    }
    if (password !== confirm) {
      setError('The new passwords do not match.')
      return
    }
    setLoading(true)
    setError('')
    try {
      await resetPassword(email.trim().toLowerCase(), code.trim(), password)
      navigate('/login', { replace: true, state: { reset: true } })
    } catch (err) {
      if (err instanceof ApiError) setError(err.message)
      else if (err instanceof TypeError) setError(unreachableApiMessage())
      else setError(err instanceof Error ? err.message : 'Could not reset the password.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div
      className="min-h-screen flex items-center justify-center p-4 relative overflow-hidden"
      style={{
        background: `linear-gradient(145deg, ${colors.backgroundAlt} 0%, ${colors.background} 45%, #fffef5 100%)`,
      }}
    >
      <div
        className="absolute inset-0 flex items-center justify-center pointer-events-none opacity-[0.06]"
        aria-hidden
      >
        <img src={assetUrl('strollwiselogo.jpg')} alt="" className="w-80 h-80 object-cover rounded-full" />
      </div>

      <form
        onSubmit={codeStep ? submitNewPassword : requestCode}
        className="relative bg-white/95 backdrop-blur-sm p-8 rounded-[28px] shadow-xl w-full max-w-md border border-white"
        style={{ boxShadow: '0 12px 24px rgba(15, 23, 42, 0.08)' }}
      >
        <BrandLogo size="md" subtitle="Admin Console" className="mb-6" />

        <h1 className="text-xl font-black text-sw-ink">Forgot password</h1>
        <p className="text-sm text-sw-muted mt-1 mb-6">
          {codeStep
            ? 'Enter the 6-digit code and choose a new password for this researcher account.'
            : 'Reset the password for this researcher account. We send a 6-digit code to the email you use to sign in.'}
        </p>

        {apiOk === false ? (
          <div className="mb-4 text-sm text-amber-900 bg-amber-50 border border-amber-200 p-3 rounded-xl">
            {isLocalApiUrl() ? (
              <>
                Backend API is not reachable. Run{' '}
                <code className="text-xs bg-white px-1 py-0.5 rounded">
                  cd backend && ./scripts/dev.sh
                </code>
              </>
            ) : (
              <>{unreachableApiMessage()}</>
            )}
          </div>
        ) : null}

        {error ? (
          <div className="mb-4 text-sm text-red-700 bg-red-50 border border-red-100 p-3 rounded-xl">
            {error}
          </div>
        ) : null}

        {hint ? (
          <div className="mb-4 text-sm text-emerald-900 bg-emerald-50 border border-emerald-200 p-3 rounded-xl">
            {hint}
          </div>
        ) : null}

        <label className="block text-sm font-bold text-sw-ink mb-1">Email</label>
        <input
          className="w-full border border-sw-border rounded-xl px-3 py-2.5 mb-4 focus:outline-none focus:ring-2 focus:ring-sw-primary/40 disabled:bg-slate-50"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          type="email"
          required
          disabled={codeStep}
        />

        {codeStep ? (
          <>
            <label className="block text-sm font-bold text-sw-ink mb-1">6-digit code</label>
            <input
              className="w-full border border-sw-border rounded-xl px-3 py-2.5 mb-4 focus:outline-none focus:ring-2 focus:ring-sw-primary/40"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              inputMode="numeric"
              autoComplete="one-time-code"
              required
            />

            <label className="block text-sm font-bold text-sw-ink mb-1">New password</label>
            <input
              className="w-full border border-sw-border rounded-xl px-3 py-2.5 mb-4 focus:outline-none focus:ring-2 focus:ring-sw-primary/40"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              type="password"
              minLength={8}
              required
            />

            <label className="block text-sm font-bold text-sw-ink mb-1">Confirm new password</label>
            <input
              className="w-full border border-sw-border rounded-xl px-3 py-2.5 mb-6 focus:outline-none focus:ring-2 focus:ring-sw-primary/40"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              type="password"
              minLength={8}
              required
            />
          </>
        ) : null}

        <Button type="submit" disabled={loading} className="w-full py-3">
          {loading ? 'Please wait…' : codeStep ? 'Update password' : 'Send reset code'}
        </Button>

        {codeStep ? (
          <button
            type="button"
            className="w-full mt-3 text-sm font-bold text-sw-primary"
            disabled={loading}
            onClick={() => requestCode()}
          >
            Send a new code
          </button>
        ) : null}

        <p className="text-center mt-4">
          <Link to="/login" className="text-sm font-bold text-sw-muted hover:text-sw-ink">
            Back to sign in
          </Link>
        </p>
      </form>
    </div>
  )
}
