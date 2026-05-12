import '../models/accommodation.dart';

class AccommodationService {
  static List<Accommodation> loadAccommodations() {
    return _rawJson.map((j) => Accommodation.fromJson(j)).toList();
  }

  static const List<Map<String, dynamic>> _rawJson = [
    {
      "name": "Cathedral Peak Hotel",
      "type": "hotel",
      "region": "Central",
      "gps": [-28.94756, 29.20655],
      "phone": "+27364881888"
    },
    {
      "name": "Champagne Castle Hotel",
      "type": "hotel",
      "region": "Central",
      "gps": [-29.04764, 29.41866],
      "phone": "+27364688000"
    },
    {
      "name": "Champagne Sports Resort",
      "type": "resort",
      "region": "Central",
      "gps": [-29.0812, 29.4125],
      "phone": "+27364688000"
    },
    {
      "name": "Dragon Peaks Mountain Resort",
      "type": "resort",
      "region": "Central",
      "gps": [-29.0165, 29.4350],
      "phone": "+27364681012"
    },
    {
      "name": "The Cavern Resort",
      "type": "resort",
      "region": "Northern",
      "gps": [-28.63598, 28.95906],
      "phone": "+27364386270"
    },
    {
      "name": "Montusi Mountain Lodge",
      "type": "lodge",
      "region": "Northern",
      "gps": [-28.6186, 28.9950],
      "phone": "+27364386243"
    },
    {
      "name": "Alpine Heath Resort",
      "type": "resort",
      "region": "Northern",
      "gps": [-28.5304, 28.9328],
      "phone": "+27364386150"
    },
    {
      "name": "Witsieshoek Mountain Lodge",
      "type": "lodge",
      "region": "Northern",
      "gps": [-28.68578, 28.89938],
      "phone": "+27587136361"
    },
    {
      "name": "Sani Pass Hotel",
      "type": "hotel",
      "region": "Southern",
      "gps": [-29.65791, 29.44622],
      "phone": "+27337020333"
    },
    {
      "name": "Drakensberg Gardens Resort",
      "type": "resort",
      "region": "Southern",
      "gps": [-29.7547, 29.2393],
      "phone": "+27337011351"
    },
    {
      "name": "Castleburn Resort",
      "type": "resort",
      "region": "Southern",
      "gps": [-29.7513, 29.2973],
      "phone": "+27337011456"
    },
    {
      "name": "Three Tree Hill Lodge",
      "type": "lodge",
      "region": "Northern",
      "gps": [-28.6616, 29.4871],
      "phone": null
    },
    {
      "name": "Spionkop Lodge",
      "type": "lodge",
      "region": "Northern",
      "gps": [-28.7054, 29.5306],
      "phone": null
    },
    {
      "name": "Qambathi Mountain Lodge",
      "type": "lodge",
      "region": "Southern",
      "gps": [-29.2844, 29.5397],
      "phone": null
    },
    {
      "name": "Penwarn Country Lodge",
      "type": "lodge",
      "region": "Southern",
      "gps": [-29.8329, 29.3874],
      "phone": null
    },
    {
      "name": "Coleford Lodge",
      "type": "lodge",
      "region": "Southern",
      "gps": [-29.9542, 29.4831],
      "phone": null
    },
    {
      "name": "Inkosana Lodge",
      "type": "backpacker",
      "region": "Central",
      "gps": [-29.0116, 29.4589],
      "phone": null
    },
    {
      "name": "Sani Lodge Backpackers",
      "type": "backpacker",
      "region": "Southern",
      "gps": [-29.6896, 29.4795],
      "phone": null
    },
    {
      "name": "Under the Berg Backpackers",
      "type": "backpacker",
      "region": "Southern",
      "gps": [-29.7521, 29.3872],
      "phone": null
    },
    {
      "name": "Bergville Caravan Park & Chalets",
      "type": "self_catering",
      "region": "Northern",
      "gps": [-28.7298, 29.3603],
      "phone": null
    },
    {
      "name": "Hlalanathi Berg Resort",
      "type": "resort",
      "region": "Northern",
      "gps": [-28.6595, 29.0322],
      "phone": null
    },
    {
      "name": "ATKV Drakensville",
      "type": "resort",
      "region": "Northern",
      "gps": [-28.6130, 29.1244],
      "phone": null
    },
    {
      "name": "Umzimkulu River Lodge",
      "type": "lodge",
      "region": "Southern",
      "gps": [-29.8849, 29.5817],
      "phone": null
    },
    {
      "name": "Didima Camp",
      "type": "resort",
      "region": "Central",
      "gps": [-28.94338, 29.23065],
      "phone": "+27364881332"
    },
    {
      "name": "Giants Castle Resort",
      "type": "resort",
      "region": "Central",
      "gps": [-29.27007, 29.51997],
      "phone": "+27363533718"
    },
    {
      "name": "Injisuthi Camp",
      "type": "resort",
      "region": "Central",
      "gps": [-29.11845, 29.44001],
      "phone": "+27364319000"
    },
    {
      "name": "Lotheni Resort",
      "type": "resort",
      "region": "Southern",
      "gps": [-29.4447, 29.6800],
      "phone": "+27337020540"
    },
    {
      "name": "Kamberg Resort",
      "type": "resort",
      "region": "Central",
      "gps": [-29.3872, 29.6734],
      "phone": "+27332637251"
    },
    {
      "name": "Mahai Campsite",
      "type": "camping",
      "region": "Northern",
      "gps": [-28.69002, 28.94595],
      "phone": "+27364386310"
    },
    {
      "name": "Tendele Camp",
      "type": "resort",
      "region": "Northern",
      "gps": [-28.7136, 28.9314],
      "phone": "+27364386411"
    },
    {
      "name": "Monk's Cowl",
      "type": "resort",
      "region": "Central",
      "gps": [-29.04700, 29.40342],
      "phone": "+27364681103"
    }
  ];
}
