// APK download URL — update this single constant for new releases
export const APK_DOWNLOAD_URL =
  'https://github.com/dataforgeailabs-ai/Product_Mart/releases/download/v1.0.0-beta.2/app-release.apk';

export const APK_VERSION = 'v1.0.0 Beta 2';
export const APK_SIZE = '50.6 MB';
export const APK_RELEASE_DATE = 'November 2026';

export const GITHUB_REPO_URL =
  'https://github.com/dataforgeailabs-ai/Product_Mart';

export const NAV_LINKS = [
  { label: 'Home', href: '#home' },
  { label: 'About', href: '#about' },
  { label: 'Features', href: '#features' },
  { label: 'How It Works', href: '#how-it-works' },
  { label: 'Contact', href: '#contact' },
];

export const FEATURES = [
  {
    id: 'marketplace',
    icon: 'ShoppingBag',
    title: 'Product Marketplace',
    description:
      'Browse the full catalogue of hotel supplies. View product details, pricing and descriptions. Add items to your cart and manage quantities with ease.',
    highlights: ['Browse hotel supplies', 'Product details & pricing', 'Cart management'],
  },
  {
    id: 'food',
    icon: 'UtensilsCrossed',
    title: 'Food Ordering',
    description:
      'Explore food items from participating restaurant partners. Browse by food category, check availability, and place food orders directly through the platform.',
    highlights: ['Browse food items', 'Food categories', 'Restaurant availability'],
  },
  {
    id: 'cart',
    icon: 'CreditCard',
    title: 'Unified Cart & Checkout',
    description:
      'Add both supplies and food to a single cart. Complete checkout through one unified flow with secure online payment powered by Razorpay.',
    highlights: ['Unified cart', 'Seamless checkout', 'Razorpay payments'],
  },
  {
    id: 'restaurant',
    icon: 'Store',
    title: 'Restaurant Management',
    description:
      'Apply to become a restaurant partner. Manage your food menu, control item availability, and update food images and details from your dashboard.',
    highlights: ['Partner application', 'Menu management', 'Availability control'],
  },
  {
    id: 'orders',
    icon: 'ClipboardList',
    title: 'Order Management',
    description:
      'Track and manage all orders in real time. View detailed order information and support end-to-end delivery operations from placement to completion.',
    highlights: ['Order tracking', 'Order details', 'Delivery support'],
  },
  {
    id: 'roles',
    icon: 'Users',
    title: 'Role-Based Dashboards',
    description:
      'Purpose-built dashboards for every stakeholder — Super Admin, Admin, Hotel/Resort, Restaurant Partner, and Delivery Personnel — each with the right tools.',
    highlights: ['Super Admin & Admin', 'Hotel / Resort', 'Restaurant & Delivery'],
  },
];

export const HOW_IT_WORKS = [
  {
    step: 1,
    icon: 'Download',
    title: 'Download MistyGo',
    description: 'Download and install the MistyGo Android app on your device.',
  },
  {
    step: 2,
    icon: 'UserPlus',
    title: 'Register & Sign In',
    description: 'Register your hotel or restaurant and sign in to your personalised dashboard.',
  },
  {
    step: 3,
    icon: 'Search',
    title: 'Browse & Explore',
    description: 'Browse hotel supplies and restaurant food items. Explore categories and product details.',
  },
  {
    step: 4,
    icon: 'PackageCheck',
    title: 'Order & Manage',
    description: 'Place orders, pay securely via Razorpay, and track deliveries in real time.',
  },
];

export const USER_TYPES = [
  {
    icon: 'Hotel',
    title: 'Hotels & Resorts',
    color: 'bg-red-50 border-red-100',
    iconColor: 'text-brand-primary',
    description:
      'Streamline your supply procurement and food ordering. Register your property, browse the full supply catalogue, place orders and track deliveries — all from one app.',
    benefits: ['Easy supply procurement', 'Food ordering for guests', 'Order history & tracking'],
  },
  {
    icon: 'ChefHat',
    title: 'Restaurant Partners',
    color: 'bg-orange-50 border-orange-100',
    iconColor: 'text-orange-600',
    description:
      'Join MistyGo as a food partner. Manage your menu, control food availability, update item images, and receive food orders from hotels and other businesses.',
    benefits: ['Easy partner onboarding', 'Menu & availability control', 'Direct order fulfilment'],
  },
  {
    icon: 'Building2',
    title: 'Hospitality Businesses',
    color: 'bg-purple-50 border-purple-100',
    iconColor: 'text-purple-600',
    description:
      'Any hospitality-focused business can connect to the MistyGo platform. Access a unified marketplace for supplies and food, backed by a robust admin infrastructure.',
    benefits: ['Unified platform access', 'Admin & super-admin controls', 'Scalable for any size'],
  },
  {
    icon: 'Bike',
    title: 'Delivery Personnel',
    color: 'bg-green-50 border-green-100',
    iconColor: 'text-green-600',
    description:
      'Manage your deliveries from a dedicated dashboard. View assigned orders, access delivery details and update order statuses on the go.',
    benefits: ['Dedicated delivery dashboard', 'Order details & routing', 'Status updates'],
  },
];
