'use client';

import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';

export default function Header() {
  const { user, isAuthenticated, logout } = useAuth();
  const router = useRouter();

  const handleLogout = async () => {
    await logout();
    router.push('/');
  };

  return (
    <header className="bg-blue-600 text-white shadow-lg">
      <nav className="container mx-auto px-4 py-4">
        <div className="flex justify-between items-center">
          <Link href="/" className="text-2xl font-bold hover:text-blue-200">
            🛒 MicroShop
          </Link>

          <div className="flex items-center space-x-6">
            <Link href="/" className="hover:text-blue-200">
              Home
            </Link>
            <Link href="/products" className="hover:text-blue-200">
              Products
            </Link>

            {isAuthenticated ? (
              <>
                <Link href="/profile" className="hover:text-blue-200">
                  Profile ({user?.first_name})
                </Link>
                <button
                  onClick={handleLogout}
                  className="bg-red-500 hover:bg-red-600 px-4 py-2 rounded"
                >
                  Logout
                </button>
              </>
            ) : (
              <>
                <Link
                  href="/login"
                  className="bg-white text-blue-600 px-4 py-2 rounded hover:bg-blue-50"
                >
                  Login
                </Link>
                <Link
                  href="/register"
                  className="bg-green-500 hover:bg-green-600 px-4 py-2 rounded"
                >
                  Register
                </Link>
              </>
            )}
          </div>
        </div>
      </nav>
    </header>
  );
}