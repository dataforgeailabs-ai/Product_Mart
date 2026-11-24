import { Hotel, ChefHat, Building2, Bike, CheckCircle2 } from 'lucide-react';
import { USER_TYPES } from '../constants';

const iconMap = { Hotel, ChefHat, Building2, Bike };

export default function WhoCanUse() {
  return (
    <section
      id="who-can-use"
      className="py-24"
      style={{ background: 'linear-gradient(180deg, #fff5f6 0%, #ffffff 100%)' }}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="inline-block px-4 py-1.5 bg-red-50 rounded-full mb-4">
            <span className="text-xs font-semibold text-[#C41E34] uppercase tracking-wider">
              Built For Everyone
            </span>
          </div>
          <h2 className="text-3xl sm:text-4xl font-extrabold text-gray-900 mb-4">
            Who Can Use{' '}
            <span
              style={{
                background: 'linear-gradient(135deg, #C41E34, #F0505F)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
              }}
            >
              MistyGo?
            </span>
          </h2>
          <p className="text-gray-500 leading-relaxed">
            MistyGo serves every stakeholder in the hospitality ecosystem with purpose-built
            tools and dashboards.
          </p>
        </div>

        {/* User type cards */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {USER_TYPES.map((type, index) => {
            const Icon = iconMap[type.icon];
            return (
              <div
                key={index}
                className={`feature-card bg-white rounded-2xl p-6 border ${type.color} shadow-sm flex flex-col`}
              >
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center mb-4 ${type.color}`}>
                  {Icon && <Icon size={22} className={type.iconColor} />}
                </div>

                <h3 className="font-bold text-gray-900 mb-3 text-base">{type.title}</h3>
                <p className="text-gray-500 text-sm leading-relaxed mb-5 flex-1">
                  {type.description}
                </p>

                <ul className="space-y-1.5">
                  {type.benefits.map((b) => (
                    <li key={b} className="flex items-start gap-2 text-xs text-gray-600">
                      <CheckCircle2 size={13} className={`${type.iconColor} mt-0.5 flex-shrink-0`} />
                      {b}
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
