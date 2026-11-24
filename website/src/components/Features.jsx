import {
  ShoppingBag,
  UtensilsCrossed,
  CreditCard,
  Store,
  ClipboardList,
  Users,
  CheckCircle2,
} from 'lucide-react';
import { FEATURES } from '../constants';

const iconMap = {
  ShoppingBag,
  UtensilsCrossed,
  CreditCard,
  Store,
  ClipboardList,
  Users,
};

const colorSchemes = [
  { bg: 'bg-red-50', icon: 'text-[#C41E34]', border: 'border-red-100', accent: 'bg-[#C41E34]' },
  { bg: 'bg-orange-50', icon: 'text-orange-600', border: 'border-orange-100', accent: 'bg-orange-500' },
  { bg: 'bg-blue-50', icon: 'text-blue-600', border: 'border-blue-100', accent: 'bg-blue-500' },
  { bg: 'bg-purple-50', icon: 'text-purple-600', border: 'border-purple-100', accent: 'bg-purple-500' },
  { bg: 'bg-green-50', icon: 'text-green-600', border: 'border-green-100', accent: 'bg-green-500' },
  { bg: 'bg-pink-50', icon: 'text-pink-600', border: 'border-pink-100', accent: 'bg-pink-500' },
];

export default function Features() {
  return (
    <section id="features" className="py-24" style={{ background: '#FAFAFA' }}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="inline-block px-4 py-1.5 bg-red-50 rounded-full mb-4">
            <span className="text-xs font-semibold text-[#C41E34] uppercase tracking-wider">
              Platform Features
            </span>
          </div>
          <h2 className="text-3xl sm:text-4xl font-extrabold text-gray-900 mb-4">
            Everything You Need,{' '}
            <span
              style={{
                background: 'linear-gradient(135deg, #C41E34, #F0505F)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
              }}
            >
              Built In
            </span>
          </h2>
          <p className="text-gray-500 leading-relaxed">
            MistyGo is a complete hospitality platform with features for every stakeholder —
            from hotel managers to restaurant partners and delivery teams.
          </p>
        </div>

        {/* Feature cards grid */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {FEATURES.map((feature, index) => {
            const Icon = iconMap[feature.icon];
            const scheme = colorSchemes[index % colorSchemes.length];
            return (
              <div
                key={feature.id}
                className={`feature-card bg-white rounded-2xl p-6 border ${scheme.border} shadow-sm flex flex-col`}
              >
                {/* Icon */}
                <div className={`w-12 h-12 ${scheme.bg} rounded-xl flex items-center justify-center mb-5`}>
                  {Icon && <Icon size={22} className={scheme.icon} />}
                </div>

                {/* Title */}
                <h3 className="text-lg font-bold text-gray-900 mb-3">{feature.title}</h3>

                {/* Description */}
                <p className="text-gray-500 text-sm leading-relaxed mb-5 flex-1">
                  {feature.description}
                </p>

                {/* Highlights */}
                <ul className="space-y-1.5">
                  {feature.highlights.map((h) => (
                    <li key={h} className="flex items-center gap-2 text-sm text-gray-600">
                      <CheckCircle2 size={14} className={scheme.icon} />
                      {h}
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
