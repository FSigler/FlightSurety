
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        //Show pre-generated flights
        var select = document.getElementById('flight-number'); 
        for(var i = 0; i < contract.preRegisteredFlights.length;i++){
            select.innerHTML += `<option value="${contract.preRegisteredFlights[i]}">${contract.preRegisteredFlights[i]}</option>`;
        }   

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // User-submitted transaction
        DOM.elid('buy-insurance').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            let value = DOM.elid('insurance').value;
            // Write transaction
            contract.buyInsurance(flight, value, (error, result) => {
                display('Passengers', 'Buy insurance', [ { label: 'Buy Insurance', error: error, value: result.flight + ' ' + result.value} ]);
            });
        })

        // User-submitted transaction
        DOM.elid('claim-credit').addEventListener('click', () => {

            // Write transaction
            contract.claimCreditRefund( (error, result) => {
                display('Passengers', 'Claim refund', [ { label: 'Claim refund', error: error, value: ""} ]);
            });
        });
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}






