import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Float "mo:base/Float";

actor AIModelMarketplace {
    // Tipe data untuk model AI
    type AIModel = {
        id: Nat;
        creator: Principal;
        name: Text;
        description: Text;
        modelType: ModelType;
        price: Nat;
        totalRatings: Nat;
        averageRating: Float;
        usageCount: Nat;
        verificationStatus: VerificationStatus;
    };

    // Tipe model AI
    type ModelType = {
        #Classification;
        #Regression;
        #NeuralNetwork;
        #GenerativeAI;
        #Other;
    };

    // Status verifikasi
    type VerificationStatus = {
        #Pending;
        #Verified;
        #Rejected;
    };

    // Tipe data rating
    type ModelRating = {
        user: Principal;
        rating: Nat8; // 1-5
        comment: Text;
        timestamp: Int;
    };

    // Tipe data lisensi penggunaan
    type UsageLicense = {
        modelId: Nat;
        user: Principal;
        purchaseTimestamp: Int;
        expirationTimestamp: Int;
    };

    // Penyimpanan model
    private var aiModels = HashMap.HashMap<Nat, AIModel>(10, Nat.equal, Nat.hash);
    private var modelRatings = HashMap.HashMap<Nat, [ModelRating]>(10, Nat.equal, Nat.hash);
    private var usageLicenses = HashMap.HashMap<Principal, [UsageLicense]>(10, Principal.equal, Principal.hash);
    private var modelCounter : Nat = 0;

    // Membuat model AI baru
    public shared(msg) func createAIModel(
        name: Text, 
        description: Text, 
        modelType: ModelType,
        price: Nat
    ) : async Result.Result<Nat, Text> {
        // Validasi input
        if (Text.size(name) == 0 or price < 0) {
            return #err("Invalid model details");
        };

        let newModel : AIModel = {
            id = modelCounter;
            creator = msg.caller;
            name = name;
            description = description;
            modelType = modelType;
            price = price;
            totalRatings = 0;
            averageRating = 0.0;
            usageCount = 0;
            verificationStatus = #Pending;
        };

        aiModels.put(modelCounter, newModel);
        modelCounter += 1;
        #ok(modelCounter - 1)
    };

    // Membeli lisensi model AI
    public shared(msg) func purchaseModelLicense(
        modelId: Nat
    ) : async Result.Result<UsageLicense, Text> {
        switch (aiModels.get(modelId)) {
            case null { return #err("Model not found"); };
            case (?model) {
                // Validasi model terverifikasi
                if (model.verificationStatus != #Verified) {
                    return #err("Model not verified for use");
                };

                let license : UsageLicense = {
                    modelId = modelId;
                    user = msg.caller;
                    purchaseTimestamp = Time.now();
                    expirationTimestamp = Time.now() + (30 * 24 * 60 * 60 * 1_000_000_000); // 30 hari
                };

                // Update daftar lisensi pengguna
                switch (usageLicenses.get(msg.caller)) {
                    case null { 
                        usageLicenses.put(msg.caller, [license]); 
                    };
                    case (?existingLicenses) {
                        usageLicenses.put(msg.caller, 
                            Array.append(existingLicenses, [license])
                        );
                    };
                };

                // Update hitungan penggunaan model
                let updatedModel : AIModel = {
                    id = model.id;
                    creator = model.creator;
                    name = model.name;
                    description = model.description;
                    modelType = model.modelType;
                    price = model.price;
                    totalRatings = model.totalRatings;
                    averageRating = model.averageRating;
                    usageCount = model.usageCount + 1;
                    verificationStatus = model.verificationStatus;
                };

                aiModels.put(modelId, updatedModel);
                #ok(license)
            };
        }
    };

    // Memberikan rating model
    public shared(msg) func rateAIModel(
        modelId: Nat, 
        rating: Nat8, 
        comment: Text
    ) : async Result.Result<ModelRating, Text> {
        // Validasi rating
        if (rating < 1 or rating > 5) {
            return #err("Invalid rating. Must be between 1-5");
        };

        switch (aiModels.get(modelId)) {
            case null { return #err("Model not found"); };
            case (?model) {
                let newRating : ModelRating = {
                    user = msg.caller;
                    rating = rating;
                    comment = comment;
                    timestamp = Time.now();
                };

                // Tambahkan rating
                switch (modelRatings.get(modelId)) {
                    case null { 
                        modelRatings.put(modelId, [newRating]); 
                    };
                    case (?existingRatings) {
                        modelRatings.put(modelId, 
                            Array.append(existingRatings, [newRating])
                        );
                    };
                };

                // Hitung ulang rating rata-rata
                let totalRating = model.totalRatings + rating;
                let averageRating = Float.fromInt(totalRating) / Float.fromInt(model.totalRatings + 1);

                let updatedModel : AIModel = {
                    id = model.id;
                    creator = model.creator;
                    name = model.name;
                    description = model.description;
                    modelType = model.modelType;
                    price = model.price;
                    totalRatings = totalRating;
                    averageRating = averageRating;
                    usageCount = model.usageCount;
                    verificationStatus = model.verificationStatus;
                };

                aiModels.put(modelId, updatedModel);
                #ok(newRating)
            };
        }
    };

    // Mendapatkan detail model
    public query func getAIModel(modelId: Nat) : async ?AIModel {
        aiModels.get(modelId)
    };

    // Mendapatkan semua model
    public query func getAllAIModels() : async [(Nat, AIModel)] {
        Iter.toArray(aiModels.entries())
    };

    // Mendapatkan rating model
    public query func getModelRatings(modelId: Nat) : async [ModelRating] {
        switch (modelRatings.get(modelId)) {
            case null { [] };
            case (?ratings) { ratings };
        }
    };
}
