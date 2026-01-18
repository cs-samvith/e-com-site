import type { Metadata } from 'next';
import './globals.css';
import { AuthProvider } from '@/contexts/AuthContext';
import Header from '@/components/Header';

export const metadata: Metadata = {
  title: 'Microservices Shop',
  description: 'E-commerce platform built with microservices',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body style={{ fontFamily: 'system-ui, -apple-system, sans-serif' }}>
        <AuthProvider>
          <div className="min-h-screen flex flex-col">
            <Header />
            <main className="flex-grow container mx-auto px-4 py-8">
              {children}
            </main>
            <footer className="bg-gray-800 text-white py-6 mt-auto">
              <div className="container mx-auto px-4 text-center">
                <p>&copy; 2026 Microservices Shop. Learning Project.</p>
              </div>
            </footer>
          </div>
        </AuthProvider>
      </body>
    </html>
  );
}