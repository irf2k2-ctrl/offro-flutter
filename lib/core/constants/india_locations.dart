// lib/core/constants/india_locations.dart
// OFFRO — Shared India State/City reference data.
//
// Extracted out of lib/screens/merchant/merchant_screens.dart (where it was
// originally defined for the merchant Add/Edit Store screen's State+City
// dropdowns) so it can also be reused by the account-level manual
// State+City entry flow in lib/screens/auth/login_screen.dart, without
// creating a circular import between the two screen files (merchant_screens
// already imports login_screen.dart for LoginScreen/ContinueAsScreen).
//
// No values changed — this is a pure relocation of the existing constants.

const Map<String, List<String>> kIndiaCities = {
  "Andhra Pradesh": ["Visakhapatnam","Vijayawada","Guntur","Nellore","Kurnool","Rajahmundry","Tirupati","Kakinada","Kadapa","Anantapur"],
  "Arunachal Pradesh": ["Itanagar","Naharlagun","Pasighat"],
  "Assam": ["Guwahati","Silchar","Dibrugarh","Jorhat","Nagaon","Tinsukia"],
  "Bihar": ["Patna","Gaya","Bhagalpur","Muzaffarpur","Purnia","Darbhanga","Bihar Sharif","Arrah"],
  "Chhattisgarh": ["Raipur","Bhilai","Bilaspur","Korba","Durg","Rajnandgaon","Jagdalpur"],
  "Goa": ["Panaji","Margao","Vasco da Gama","Mapusa","Ponda"],
  "Gujarat": ["Ahmedabad","Surat","Vadodara","Rajkot","Bhavnagar","Jamnagar","Gandhinagar","Junagadh","Anand"],
  "Haryana": ["Faridabad","Gurugram","Panipat","Ambala","Yamunanagar","Rohtak","Hisar","Karnal","Sonipat","Panchkula"],
  "Himachal Pradesh": ["Shimla","Solan","Dharamshala","Mandi","Baddi","Palampur","Kullu"],
  "Jharkhand": ["Ranchi","Jamshedpur","Dhanbad","Bokaro","Deoghar","Hazaribagh"],
  "Karnataka": ["Bengaluru","Mysuru","Mangaluru","Hubli","Dharwad","Belagavi","Kalaburagi","Ballari","Vijayapura","Shivamogga","Tumkur","Davangere","Hassan","Udupi"],
  "Kerala": ["Thiruvananthapuram","Kochi","Kozhikode","Thrissur","Kollam","Kannur","Palakkad","Alappuzha","Malappuram","Kottayam"],
  "Madhya Pradesh": ["Bhopal","Indore","Jabalpur","Gwalior","Ujjain","Sagar","Dewas","Satna","Ratlam","Rewa"],
  "Maharashtra": ["Mumbai","Pune","Nagpur","Nashik","Thane","Aurangabad","Solapur","Kolhapur","Amravati","Nanded","Sangli","Malegaon","Jalgaon","Akola","Latur"],
  "Manipur": ["Imphal","Thoubal","Bishnupur","Churachandpur"],
  "Meghalaya": ["Shillong","Tura","Jowai"],
  "Mizoram": ["Aizawl","Lunglei","Champhai"],
  "Nagaland": ["Kohima","Dimapur","Mokokchung"],
  "Odisha": ["Bhubaneswar","Cuttack","Rourkela","Berhampur","Sambalpur","Puri","Balasore"],
  "Punjab": ["Ludhiana","Amritsar","Jalandhar","Patiala","Bathinda","Mohali","Firozpur","Hoshiarpur"],
  "Rajasthan": ["Jaipur","Jodhpur","Kota","Bikaner","Ajmer","Udaipur","Bhilwara","Alwar","Bharatpur","Sikar"],
  "Sikkim": ["Gangtok","Namchi","Gyalshing"],
  "Tamil Nadu": ["Chennai","Coimbatore","Madurai","Tiruchirappalli","Salem","Tirunelveli","Vellore","Erode","Thoothukudi","Tiruppur","Dindigul","Thanjavur"],
  "Telangana": ["Hyderabad","Warangal","Nizamabad","Karimnagar","Ramagundam","Khammam","Mahbubnagar","Nalgonda","Adilabad"],
  "Tripura": ["Agartala","Dharmanagar","Udaipur"],
  "Uttar Pradesh": ["Lucknow","Kanpur","Agra","Varanasi","Prayagraj","Meerut","Bareilly","Aligarh","Ghaziabad","Noida","Mathura","Moradabad","Gorakhpur"],
  "Uttarakhand": ["Dehradun","Haridwar","Roorkee","Haldwani","Rishikesh","Nainital","Kashipur","Rudrapur"],
  "West Bengal": ["Kolkata","Asansol","Siliguri","Durgapur","Bardhaman","Malda","Baharampur","Kharagpur"],
  "Delhi": ["New Delhi","Dwarka","Rohini","Pitampura","Laxmi Nagar","Janakpuri","Saket","Karol Bagh","Connaught Place"],
  "Jammu and Kashmir": ["Srinagar","Jammu","Anantnag","Baramulla","Sopore","Kathua"],
  "Ladakh": ["Leh","Kargil"],
  "Andaman and Nicobar Islands": ["Port Blair","Diglipur","Rangat"],
  "Chandigarh": ["Chandigarh"],
  "Dadra and Nagar Haveli and Daman and Diu": ["Daman","Diu","Silvassa"],
  "Lakshadweep": ["Kavaratti","Agatti"],
  "Puducherry": ["Puducherry","Karaikal","Mahe","Yanam"],
};

const List<String> kIndiaStates = [
  "Andhra Pradesh","Arunachal Pradesh","Assam","Bihar","Chhattisgarh",
  "Goa","Gujarat","Haryana","Himachal Pradesh","Jharkhand",
  "Karnataka","Kerala","Madhya Pradesh","Maharashtra","Manipur",
  "Meghalaya","Mizoram","Nagaland","Odisha","Punjab",
  "Rajasthan","Sikkim","Tamil Nadu","Telangana","Tripura",
  "Uttar Pradesh","Uttarakhand","West Bengal","Delhi",
  "Jammu and Kashmir","Ladakh","Andaman and Nicobar Islands",
  "Chandigarh","Dadra and Nagar Haveli and Daman and Diu",
  "Lakshadweep","Puducherry",
];
