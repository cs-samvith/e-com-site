import api from './api';
import { Product, ProductCreate } from '@/types';

export const productService = {
  /**
   * Get all products
   */
  getProducts: async (limit = 100, offset = 0): Promise<Product[]> => {
    const response = await api.get(`/api/products?limit=${limit}&offset=${offset}`);
    return response.data;
  },

  /**
   * Get single product by ID
   */
  getProduct: async (id: string): Promise<Product> => {
    const response = await api.get(`/api/products/${id}`);
    return response.data;
  },

  /**
   * Search products
   */
  searchProducts: async (query: string): Promise<Product[]> => {
    const response = await api.get(`/api/products/search?q=${encodeURIComponent(query)}`);
    return response.data;
  },

  /**
   * Create new product (admin only)
   */
  createProduct: async (product: ProductCreate): Promise<Product> => {
    const response = await api.post('/api/products', product);
    return response.data;
  },

  /**
   * Update product (admin only)
   */
  updateProduct: async (id: string, updates: Partial<ProductCreate>): Promise<Product> => {
    const response = await api.put(`/api/products/${id}`, updates);
    return response.data;
  },

  /**
   * Delete product (admin only)
   */
  deleteProduct: async (id: string): Promise<void> => {
    await api.delete(`/api/products/${id}`);
  },

  /**
   * Get product inventory
   */
  getInventory: async (id: string): Promise<{ product_id: string; inventory_count: number }> => {
    const response = await api.get(`/api/products/${id}/inventory`);
    return response.data;
  },
};