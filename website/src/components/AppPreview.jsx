export default function AppPreview() {
  const screens = [
    {
      title: 'Product Marketplace',
      appBar: 'Products',
      content: 'marketplace',
    },
    {
      title: 'Food Ordering',
      appBar: 'Food',
      content: 'food',
    },
    {
      title: 'Admin Dashboard',
      appBar: 'Admin Dashboard',
      content: 'admin',
    },
  ];

  return (
    <section
      id="preview"
      className="py-24"
      style={{ background: '#1a1a2e' }}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="inline-block px-4 py-1.5 bg-white/10 rounded-full mb-4">
            <span className="text-xs font-semibold text-red-300 uppercase tracking-wider">
              App Preview
            </span>
          </div>
          <h2 className="text-3xl sm:text-4xl font-extrabold text-white mb-4">
            See MistyGo in Action
          </h2>
          <p className="text-gray-400 leading-relaxed">
            A clean, intuitive interface designed for hospitality professionals on the go.
          </p>
        </div>

        {/* Phones row */}
        <div className="flex flex-col sm:flex-row gap-8 justify-center items-center sm:items-end">
          {screens.map((screen, index) => (
            <div
              key={index}
              className={`flex flex-col items-center gap-4 ${
                index === 1 ? 'sm:-mt-8' : 'opacity-80'
              }`}
              style={{
                transform: index === 0 ? 'rotate(-4deg)' : index === 2 ? 'rotate(4deg)' : 'none',
              }}
            >
              <MiniPhone screen={screen} isCenter={index === 1} />
              <div className="text-center">
                <p className="text-sm font-medium text-gray-300">{screen.title}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Disclaimer */}
        <p className="text-center text-gray-500 text-xs mt-10">
          UI mockup for illustration. Actual app interface may vary.
        </p>
      </div>
    </section>
  );
}

function MiniPhone({ screen, isCenter }) {
  const scale = isCenter ? 'w-56' : 'w-48';

  return (
    <div
      className={`${scale} bg-gray-900 rounded-[36px] p-2.5 shadow-2xl`}
      style={{ border: `6px solid ${isCenter ? '#C41E34' : '#2a2a3e'}` }}
    >
      {/* Notch */}
      <div className="bg-black rounded-t-[28px] rounded-b-sm h-5 flex items-center justify-center mb-0.5">
        <div className="w-16 h-3 bg-gray-900 rounded-full" />
      </div>

      {/* Screen */}
      <div
        className="rounded-[22px] overflow-hidden"
        style={{ aspectRatio: '9/19', background: '#FFFBFB' }}
      >
        {/* App bar */}
        <div className="bg-[#C41E34] px-3 py-2.5 flex items-center gap-2">
          <img src="/brand/mark-white.png" alt="" className="h-4 w-4 object-contain" />
          <span className="text-white text-xs font-semibold truncate">{screen.appBar}</span>
        </div>

        {/* Screen-specific content */}
        <div className="p-2 space-y-2">
          {screen.content === 'marketplace' && <MarketplacePreview />}
          {screen.content === 'food' && <FoodPreview />}
          {screen.content === 'admin' && <AdminPreview />}
        </div>
      </div>

      {/* Home bar */}
      <div className="flex justify-center mt-2">
        <div className="w-12 h-1 bg-gray-600 rounded-full" />
      </div>
    </div>
  );
}

function MarketplacePreview() {
  return (
    <>
      <div className="flex gap-1">
        {['All', 'Linen', 'Kitchen'].map((c, i) => (
          <div
            key={c}
            className={`px-2 py-0.5 rounded-full text-[9px] font-medium ${
              i === 0 ? 'bg-[#C41E34] text-white' : 'bg-gray-100 text-gray-400'
            }`}
          >
            {c}
          </div>
        ))}
      </div>
      {[
        { name: 'Hotel Linen Set', price: '₹1,200', emoji: '🛏️' },
        { name: 'Toiletry Kit', price: '₹480', emoji: '🧴' },
        { name: 'Kitchen Supplies', price: '₹850', emoji: '🍳' },
      ].map((item) => (
        <div
          key={item.name}
          className="bg-white rounded-lg p-1.5 flex items-center gap-1.5 shadow-sm border border-gray-50"
        >
          <div className="w-7 h-7 bg-red-50 rounded-md flex items-center justify-center text-sm flex-shrink-0">
            {item.emoji}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-[9px] font-semibold text-gray-800 truncate">{item.name}</div>
            <div className="text-[9px] text-[#C41E34] font-bold">{item.price}</div>
          </div>
          <div className="w-4 h-4 bg-[#C41E34] rounded-full flex items-center justify-center flex-shrink-0">
            <span className="text-white text-[8px] font-bold">+</span>
          </div>
        </div>
      ))}
    </>
  );
}

function FoodPreview() {
  return (
    <>
      <div className="flex gap-1">
        {['All', 'Rice', 'Snacks'].map((c, i) => (
          <div
            key={c}
            className={`px-2 py-0.5 rounded-full text-[9px] font-medium ${
              i === 0 ? 'bg-[#C41E34] text-white' : 'bg-gray-100 text-gray-400'
            }`}
          >
            {c}
          </div>
        ))}
      </div>
      {[
        { name: 'Chicken Biryani', price: '₹280', emoji: '🍗' },
        { name: 'Paneer Butter Masala', price: '₹220', emoji: '🍛' },
        { name: 'Veg Pulao', price: '₹160', emoji: '🌿' },
      ].map((item) => (
        <div
          key={item.name}
          className="bg-white rounded-lg p-1.5 flex items-center gap-1.5 shadow-sm border border-gray-50"
        >
          <div className="w-7 h-7 bg-orange-50 rounded-md flex items-center justify-center text-sm flex-shrink-0">
            {item.emoji}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-[9px] font-semibold text-gray-800 truncate">{item.name}</div>
            <div className="text-[9px] text-orange-500 font-bold">{item.price}</div>
          </div>
          <div className="w-4 h-4 bg-orange-500 rounded-full flex items-center justify-center flex-shrink-0">
            <span className="text-white text-[8px] font-bold">+</span>
          </div>
        </div>
      ))}
    </>
  );
}

function AdminPreview() {
  const items = [
    { label: 'Manage Products', icon: '📦' },
    { label: 'Manage Orders', icon: '📋' },
    { label: 'Manage Hotels', icon: '🏨' },
    { label: 'Manage Users', icon: '👥' },
    { label: 'Restaurant Requests', icon: '🍽️' },
  ];
  return (
    <div className="space-y-1.5">
      {items.map((item) => (
        <div
          key={item.label}
          className="bg-white rounded-lg p-2 flex items-center gap-2 shadow-sm border border-gray-50"
        >
          <span className="text-sm">{item.icon}</span>
          <span className="text-[9px] font-medium text-gray-700">{item.label}</span>
          <span className="ml-auto text-gray-300 text-[9px]">›</span>
        </div>
      ))}
    </div>
  );
}
