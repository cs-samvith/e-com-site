import api from './api';
import { User, UserRegister, UserLogin, AuthToken, PasswordUpdate } from '@/types';
import { authUtils } from '@/utils/auth';

export const userService = {
  /**
   * Register new user
   */
  register: async (userData: UserRegister): Promise<User> => {
    const response = await api.post('/api/users/register', userData);
    return response.data;
  },

  /**
   * Login user
   */
  login: async (credentials: UserLogin): Promise<AuthToken> => {
    const response = await api.post('/api/users/login', credentials);
    const token = response.data;
    
    // Store token
    authUtils.setToken(token.access_token);
    
    return token;
  },

  /**
   * Logout user
   */
  logout: async (): Promise<void> => {
    try {
      await api.post('/api/users/logout');
    } finally {
      // Clear local auth data regardless of API call result
      authUtils.clearAuth();
    }
  },

  /**
   * Get current user profile
   */
  getProfile: async (): Promise<User> => {
    const response = await api.get('/api/users/profile');
    const user = response.data;
    
    // Store user data
    authUtils.setUser(user);
    
    return user;
  },

  /**
   * Update user profile
   */
  updateProfile: async (updates: Partial<User>): Promise<User> => {
    const response = await api.put('/api/users/profile', updates);
    const user = response.data;
    
    // Update stored user data
    authUtils.setUser(user);
    
    return user;
  },

  /**
   * Change password
   */
  changePassword: async (passwordData: PasswordUpdate): Promise<void> => {
    await api.put('/api/users/password', passwordData);
  },

  /**
   * Get all users (admin endpoint)
   */
  getUsers: async (limit = 100, offset = 0): Promise<User[]> => {
    const response = await api.get(`/api/users?limit=${limit}&offset=${offset}`);
    return response.data;
  },

  /**
   * Get user by ID
   */
  getUser: async (id: string): Promise<User> => {
    const response = await api.get(`/api/users/${id}`);
    return response.data;
  },
};