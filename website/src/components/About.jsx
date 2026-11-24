import { Hotel, UtensilsCrossed, Truck, Settings } from 'lucide-react';

const pillars = [
  {
    icon: Hotel,
    title: 'Hospitality Supply',
    description: 'Simplify procurement of hotel supplies with a curated product marketplace.',
  },
  {
    icon: UtensilsCrossed,
    title: 'Food Ordering',
    description: 'Connect hotels and restaurants for seamless food ordering and delivery.',
  },
  {
    icon: Truck,
    title: 'Delivery Operations',
    description: 'End-to-end delivery management from order placement to completion.',
  },
  {
    icon: Settings,
    title: 'Unified Platform',
    description: 'One platform that connects all stakeholders in the hospitality ecosystem.',
  },
];

export default function About() {
  return (
    <section id="about" className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Left: Text content */}
          <div>
            <div className="inline-block px-4 py-1.5 bg-red-50 rounded-full mb-4">
              <span className="text-xs font-semibold text-[#C41E34] uppercase tracking-wider">
                About MistyGo
              </span>
            </div>

            <h2 className="text-3xl sm:text-4xl font-extrabold text-gray-900 leading-tight mb-6">
              A Smarter Way to Run Your{' '}
              <span
                style={{
                  background: 'linear-gradient(135deg, #C41E34, #F0505F)',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                }}
              >
                Hospitality Business
              </span>
            </h2>

            <p className="text-gray-500 leading-relaxed mb-5 text-base">
              MistyGo is a hospitality-focused platform designed to connect hotels, resorts,
              restaurants and delivery operations through one unified digital experience.
            </p>

            <p className="text-gray-500 leading-relaxed mb-8 text-base">
              Whether you are a hotel manager ordering supplies, a restaurant partner managing
              your menu, or a delivery person fulfilling orders — MistyGo brings the entire
              hospitality supply and food ecosystem into a single, easy-to-use Android app.
            </p>

            <div className="flex flex-wrap gap-3">
              {['Hotels & Resorts', 'Restaurants', 'Delivery Partners', 'Admins'].map((tag) => (
                <span
                  key={tag}
                  className="px-4 py-1.5 bg-red-50 text-[#C41E34] text-sm font-medium rounded-full border border-red-100"
                >
                  {tag}
                </span>
              ))}
            </div>
          </div>

          {/* Right: Pillars grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
            {pillars.map((p, i) => {
              const Icon = p.icon;
              return (
                <div
                  key={i}
                  className="feature-card p-6 bg-white rounded-2xl border border-gray-100 shadow-sm hover:border-red-100"
                >
                  <div className="w-12 h-12 bg-red-50 rounded-xl flex items-center justify-center mb-4">
                    <Icon size={22} className="text-[#C41E34]" />
                  </div>
                  <h3 className="font-bold text-gray-900 mb-2 text-base">{p.title}</h3>
                  <p className="text-gray-500 text-sm leading-relaxed">{p.description}</p>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
