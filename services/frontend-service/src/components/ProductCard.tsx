'use client';

import { Product } from '@/types';

interface ProductCardProps {
  product: Product;
}

export default function ProductCard({ product }: ProductCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow">
      <div className="mb-4">
        <h3 className="text-xl font-bold mb-2">{product.name}</h3>
        <p className="text-gray-600 text-sm mb-2">{product.description}</p>
        <span className="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">
          {product.category}
        </span>
      </div>

      <div className="flex justify-between items-center">
        <div>
          <p className="text-2xl font-bold text-green-600">
            ${product.price.toFixed(2)}
          </p>
          <p className="text-sm text-gray-500">
            Stock: {product.inventory_count}
          </p>
        </div>
        <button
          className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
          disabled={product.inventory_count === 0}
        >
          {product.inventory_count > 0 ? 'Add to Cart' : 'Out of Stock'}
        </button>
      </div>
    </div>
  );
}