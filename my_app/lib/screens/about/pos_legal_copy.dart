class PosLegalSection {
  const PosLegalSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

const posLegalUpdated = '8 October 2026';
const posLegalEntity = 'Sirixo Software Technologies Pvt Ltd';
const posLegalProduct = 'SELFX — A Product of SIRIXO';
const posLegalEmail = 'hello@selfx.in';
const posPrivacyEmail = 'privacy@selfx.in';
const posLegalPhone = '+91 9988223919  ·  +91 912 912 7555';
const posLegalWeb = 'https://selfx.in';

const posTermsIntro =
    'These Terms & Conditions (“Terms”) govern your access to and use of SELFX software, applications, cloud services, APIs, hardware integrations and related services (“Services”) provided by Sirixo Software Technologies Pvt Ltd (“SELFX”, “SIRIXO”, “we”, “us” or “our”). By registering, purchasing, installing or using SELFX, you agree to these Terms.';

const posTermsSections = <PosLegalSection>[
  PosLegalSection('1. Services', [
    'SELFX provides technology solutions for restaurants, hotels, institutions and other businesses, including POS, billing, QR ordering, self-ordering kiosks, KDS, online ordering, digital menus, delivery, AI ordering, vending and related services.',
    'Features and availability depend on your selected plan and configuration.',
  ]),
  PosLegalSection('2. Account responsibility', [
    'You are responsible for:',
    '• Providing accurate account information',
    '• Keeping login credentials secure',
    '• Managing authorized users and permissions',
    '• All activity performed through your account',
    'You must notify us of any suspected unauthorized access.',
  ]),
  PosLegalSection('3. Customer data & privacy', [
    'You retain ownership of the business and customer data you submit to SELFX.',
    'SELFX may process such data only as necessary to provide, secure, maintain and improve the Services and comply with applicable law.',
    'Personal data will be handled in accordance with applicable Indian data-protection laws and our Privacy Policy.',
    'You are responsible for obtaining required permissions and consents for personal data collected through your business.',
  ]),
  PosLegalSection('4. Acceptable use', [
    'You must not:',
    '• Use SELFX for unlawful or fraudulent purposes',
    '• Attempt unauthorized access',
    '• Reverse engineer or copy the software',
    '• Introduce malware or harmful code',
    '• Abuse APIs or interfere with the Services',
    '• Resell or redistribute SELFX without authorization',
    '• Violate the rights of others',
    'We may suspend access for serious violations or security risks.',
  ]),
  PosLegalSection('5. Subscriptions & payments', [
    'SELFX may offer free trials, monthly, annual, device-based, transaction-based and enterprise plans.',
    'Subscription fees, taxes and applicable charges will be communicated at the time of purchase.',
    'Subscriptions may automatically renew unless cancelled according to the applicable plan.',
    'Failure to pay may result in suspension of Services.',
  ]),
  PosLegalSection('6. Refunds & cancellation', [
    'Cancellation and refunds are subject to the applicable subscription, commercial and Refund Policy terms.',
    'Unless otherwise agreed, prepaid subscription, installation, customization and professional-service fees are generally non-refundable.',
    'Purchases made through third-party stores or payment providers may also be subject to their respective policies.',
  ]),
  PosLegalSection('7. Hardware & third-party services', [
    'SELFX may integrate with printers, kiosks, payment systems, delivery platforms, APIs, cloud services, AI providers and other third-party services.',
    'Third-party services are controlled by their respective providers. SELFX is not responsible for outages, pricing changes, API changes or failures caused by third parties.',
    'Hardware compatibility depends on the supported device, operating system, drivers, network and configuration.',
  ]),
  PosLegalSection('8. AI features', [
    'Some SELFX features may use AI, including AI ordering and automated assistance.',
    'AI-generated results may contain errors. Customers should review important outputs before relying on them for business or customer-facing decisions.',
  ]),
  PosLegalSection('9. Service availability', [
    'We aim to provide reliable Services but do not guarantee uninterrupted or error-free operation.',
    'Services may be temporarily affected by maintenance, internet failures, hardware problems, third-party outages, cybersecurity incidents or events beyond our reasonable control.',
    'Enterprise customers may have separate SLA terms.',
  ]),
  PosLegalSection('10. Intellectual property', [
    'SELFX/SIRIXO and its licensors retain all rights to the software, technology, designs, trademarks, APIs, documentation and related intellectual property.',
    'Customers receive only the right to use the Services during the applicable subscription or agreement period.',
    'Customer data and content remain the property of the Customer.',
  ]),
  PosLegalSection('11. Security', [
    'SELFX maintains reasonable security measures appropriate to the Services.',
    'Customers are responsible for securing their devices, passwords, user accounts, networks and API credentials.',
    'No internet-based service can be guaranteed to be completely secure.',
  ]),
  PosLegalSection('12. Termination', [
    'We may suspend or terminate Services for non-payment, material breach, unlawful use, security risks or discontinuation of the relevant Service.',
    'After termination, access to the Services may be disabled and Customer Data may be retained or deleted according to applicable law and our retention policies.',
  ]),
  PosLegalSection('13. Disclaimer', [
    'SELFX is provided on an “AS IS” and “AS AVAILABLE” basis to the maximum extent permitted by law.',
    'We do not guarantee that the Services will always be available, error-free, compatible with every device or result in any particular business outcome.',
  ]),
  PosLegalSection('14. Limitation of liability', [
    'To the maximum extent permitted by law, SELFX/SIRIXO will not be liable for indirect, incidental or consequential losses, including loss of profits, revenue or business opportunities.',
    'Our total liability will not exceed the fees actually paid by the Customer to SELFX during the six (6) months preceding the event giving rise to the claim, except where liability cannot legally be limited.',
  ]),
  PosLegalSection('15. Changes to services & terms', [
    'We may update the Services, features, pricing and these Terms from time to time.',
    'Material changes will be communicated where appropriate. Continued use of SELFX after the effective date of updated Terms constitutes acceptance of the revised Terms, subject to applicable law.',
  ]),
  PosLegalSection('16. Governing law', [
    'These Terms are governed by the laws of India.',
    'Subject to applicable law and any separate enterprise agreement, courts in Hyderabad, Telangana, India shall have jurisdiction.',
  ]),
];

const posPrivacyIntro =
    'This policy explains how SELFX, a product of SIRIXO, handles personal information when you use the Services. We collect only information reasonably required to provide and improve our Services.';

const posPrivacySections = <PosLegalSection>[
  PosLegalSection('1. Information we collect', [
    'Depending on how you use SELFX, we may collect:',
    '• Name, phone number and email address',
    '• Business and organization information',
    '• Account and login information',
    '• Billing and subscription information',
    '• Order, transaction and invoice information',
    '• Customer and employee information entered by our customers',
    '• Device, browser, IP address and technical information',
    '• Location information where required for specific features',
    '• Support requests and communications',
    '• Information generated through your use of SELFX',
    '• Information provided through third-party integrations',
  ]),
  PosLegalSection('2. How we use information', [
    'We may use information to:',
    '• Provide and operate SELFX',
    '• Process orders and transactions',
    '• Manage accounts and subscriptions',
    '• Provide customer support',
    '• Send service-related communications',
    '• Improve performance and security',
    '• Prevent fraud, misuse and unauthorized access',
    '• Provide analytics and reports',
    '• Maintain and improve our products',
    '• Comply with applicable laws and legal requirements',
    'We do not sell personal information as a standalone commercial product.',
  ]),
  PosLegalSection('3. Customer data', [
    'Businesses using SELFX may enter information about their customers, employees and other individuals into the platform.',
    'The business using SELFX is generally responsible for determining why such information is collected and for providing appropriate notices and obtaining required permissions where applicable.',
    'SELFX processes such information to provide the Services and according to the applicable agreement with the business.',
  ]),
  PosLegalSection('4. AI & automated features', [
    'Some SELFX services may use AI technologies, including AI Phone Ordering, automated assistance, speech processing and other intelligent features.',
    'Information may be processed by SELFX or relevant technology providers to provide these features.',
    'AI-generated results may not always be accurate. Customers should review important outputs before relying on them.',
  ]),
  PosLegalSection('5. Third-party services', [
    'SELFX may integrate with third-party services such as payment gateways, delivery platforms, restaurant platforms, messaging providers, cloud infrastructure, AI and telephony providers, analytics services and app stores.',
    'Information shared with third parties is limited to what is reasonably required for the relevant service.',
    'Third-party providers operate under their own privacy policies and terms.',
  ]),
  PosLegalSection('6. Payments', [
    'Payment information may be processed directly by payment gateways, banks or other authorized payment providers.',
    'SELFX generally does not store complete card information unless specifically required and legally permitted for an applicable service.',
    'Payment providers may collect and process information according to their own policies.',
  ]),
  PosLegalSection('7. Cookies & technology', [
    'Our websites and applications may use cookies, device identifiers, analytics tools and similar technologies to keep services functioning, remember preferences, understand usage, improve performance and maintain security.',
    'You may be able to control cookies through your browser or device settings.',
  ]),
  PosLegalSection('8. Data security', [
    'We use reasonable technical and organizational measures designed to protect personal information against unauthorized access, misuse, loss or disclosure.',
    'However, no online system can be guaranteed to be completely secure.',
  ]),
  PosLegalSection('9. Data retention', [
    'We retain information only for as long as reasonably necessary to provide the Services, maintain business records, meet contractual obligations, resolve disputes, prevent fraud and comply with applicable legal requirements.',
    'When information is no longer required, it may be deleted, anonymized or securely archived.',
  ]),
  PosLegalSection('10. Your rights', [
    'Subject to applicable law, individuals may have rights regarding their personal information, including rights to:',
    '• Request access to information',
    '• Request correction of inaccurate information',
    '• Request deletion where applicable',
    '• Withdraw consent where processing is based on consent',
    '• Raise privacy-related concerns or complaints',
    'Requests may be submitted using the contact information below.',
  ]),
  PosLegalSection('11. Children’s data', [
    'SELFX is primarily intended for businesses and their users.',
    'We do not knowingly collect personal information directly from children for independent use of SELFX.',
    'If you believe a child’s information has been provided to us improperly, please contact us.',
  ]),
  PosLegalSection('12. Data transfers', [
    'Depending on the Services used, information may be processed or stored in India or other countries where SELFX or its service providers operate.',
    'Where required, appropriate safeguards will be applied in accordance with applicable law.',
  ]),
  PosLegalSection('13. Data breaches & security incidents', [
    'If we become aware of a personal-data breach affecting individuals, we will take appropriate steps to investigate, contain and respond to the incident and provide notifications where required by applicable law.',
  ]),
  PosLegalSection('14. Changes to this policy', [
    'We may update this Privacy Policy from time to time to reflect changes in our Services, technology or applicable laws.',
    'The latest version will be published through our website or application.',
  ]),
  PosLegalSection('15. Contact & privacy requests', [
    'Where required by applicable law, SELFX may appoint or identify a designated Data Protection Officer or Grievance Officer and publish their contact details through the appropriate channel.',
  ]),
];
