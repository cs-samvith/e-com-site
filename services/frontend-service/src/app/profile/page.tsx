'use client';

import { useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';

export default function ProfilePage() {
  const { user, isAuthenticated, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isAuthenticated, loading, router]);

  if (loading || !user) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">My Profile</h1>

      <div className="bg-white rounded-lg shadow-lg p-8">
        <div className="space-y-4">
          <div>
            <label className="block text-gray-600 text-sm mb-1">Email</label>
            <p className="text-lg font-semibold">{user.email}</p>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-gray-600 text-sm mb-1">First Name</label>
              <p className="text-lg font-semibold">{user.first_name}</p>
            </div>
            <div>
              <label className="block text-gray-600 text-sm mb-1">Last Name</label>
              <p className="text-lg font-semibold">{user.last_name}</p>
            </div>
          </div>

          {user.phone && (
            <div>
              <label className="block text-gray-600 text-sm mb-1">Phone</label>
              <p className="text-lg font-semibold">{user.phone}</p>
            </div>
          )}

          <div>
            <label className="block text-gray-600 text-sm mb-1">Member Since</label>
            <p className="text-lg font-semibold">
              {new Date(user.created_at).toLocaleDateString()}
            </p>
          </div>
        </div>

        <div className="mt-8 pt-6 border-t">
          <h2 className="text-xl font-bold mb-4">Actions</h2>
          <div className="space-y-2">
            <button className="w-full bg-blue-500 text-white py-2 rounded hover:bg-blue-600">
              Edit Profile
            </button>
            <button className="w-full bg-yellow-500 text-white py-2 rounded hover:bg-yellow-600">
              Change Password
            </button>
          </div>
        </div>
      </div>

      <div className="mt-6 bg-blue-50 rounded-lg p-6">
        <h2 className="text-xl font-bold mb-2">Account Details</h2>
        <div className="text-sm text-gray-600 space-y-1">
          <p><strong>User ID:</strong> {user.id}</p>
          <p><strong>Created:</strong> {new Date(user.created_at).toLocaleString()}</p>
          <p><strong>Last Updated:</strong> {new Date(user.updated_at).toLocaleString()}</p>
        </div>
      </div>
    </div>
  );
}
