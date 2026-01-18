'use client';

import { useAuth } from '@/contexts/AuthContext';
import Link from 'next/link';

export default function Home() {
  const { user, isAuthenticated } = useAuth();

  return (
    <div className="text-center">
      <h1 className="text-5xl font-bold mb-6">
        Welcome to MicroShop
      </h1>

      {isAuthenticated ? (
        <div className="space-y-4">
          <p className="text-xl text-gray-600">
            Hello, {user?.first_name} {user?.last_name}!
          </p>
          <p className="text-lg text-gray-500">
            Start shopping or manage your profile
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          <p className="text-xl text-gray-600">
            A microservices-based e-commerce platform
          </p>
          <p className="text-lg text-gray-500">
            Please login or register to start shopping
          </p>
        </div>
      )}

      <div className="mt-10 grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
        <div className="bg-white p-6 rounded-lg shadow-lg">
          <div className="text-4xl mb-4">📦</div>
          <h3 className="text-xl font-bold mb-2">Product Service</h3>
          <p className="text-gray-600">
            Browse our catalog of products with real-time inventory
          </p>
          <Link
            href="/products"
            className="inline-block mt-4 bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
          >
            View Products
          </Link>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-lg">
          <div className="text-4xl mb-4">👤</div>
          <h3 className="text-xl font-bold mb-2">User Service</h3>
          <p className="text-gray-600">
            Secure authentication and user management
          </p>
          {isAuthenticated ? (
            <Link
              href="/profile"
              className="inline-block mt-4 bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
            >
              My Profile
            </Link>
          ) : (
            <Link
              href="/register"
              className="inline-block mt-4 bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600"
            >
              Get Started
            </Link>
          )}
        </div>

        <div className="bg-white p-6 rounded-lg shadow-lg">
          <div className="text-4xl mb-4">🚀</div>
          <h3 className="text-xl font-bold mb-2">Kubernetes</h3>
          <p className="text-gray-600">
            Deployed with K8s, HPA, KEDA, and Istio service mesh
          </p>
          <div className="mt-4 text-sm text-gray-500">
            Learning Platform
          </div>
        </div>
      </div>

      <div className="mt-12 p-6 bg-blue-50 rounded-lg max-w-2xl mx-auto">
        <h2 className="text-2xl font-bold mb-4">Architecture</h2>
        <ul className="text-left space-y-2 text-gray-700">
          <li>✅ Next.js 14 Frontend (Port 3000)</li>
          <li>✅ User Service - FastAPI (Port 8080)</li>
          <li>✅ Product Service - FastAPI (Port 8081)</li>
          <li>✅ PostgreSQL Database</li>
          <li>✅ Redis Cache</li>
          <li>✅ RabbitMQ Message Queue</li>
          <li>✅ Prometheus & Grafana Monitoring</li>
          <li>✅ Istio Service Mesh with mTLS</li>
        </ul>
      </div>
    </div>
  );
}