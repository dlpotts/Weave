/*
Weave (Web-based Analysis and Visualization Environment)
Copyright (C) 2008-2011 University of Massachusetts Lowell

This file is a part of Weave.

Weave is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License, Version 3,
as published by the Free Software Foundation.

Weave is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/
/**
 * Makes calls to R to carry out kmeans clustering
 * Takes columns as input
 * returns clustering object 
 * 
 * 
 * @spurushe
 * */

package weave.ui.DataMiningEditors
{
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.ObjectUtil;
	
	import weave.Weave;
	import weave.api.data.IQualifiedKey;
	import weave.api.reportError;
	import weave.core.LinkableHashMap;
	import weave.data.AttributeColumns.CSVColumn;
	import weave.data.AttributeColumns.StringColumn;
	import weave.services.WeaveRServlet;
	import weave.services.addAsyncResponder;
	import weave.services.beans.KMeansClusteringResult;
	import weave.services.beans.RResult;
	import weave.utils.VectorUtils;

	public class KMeansClustering
	{
		public const identifier:String = "KMeansClustering";// helps in identifying this object in a dictionary
		private var algoCaller:Object;//this identifies which UI component is calling the kMeans i.e. the Data Mining Platter or the KMeansClusteringEditor
		
		public const inputColumns:LinkableHashMap = null;
		private var Rservice:WeaveRServlet = new WeaveRServlet(Weave.properties.rServiceURL.value);
		public var finalResult:KMeansClusteringResult;
		
		public var checkingIfFilled:Function;
		
		public var kMeansScript:String = "frame <- data.frame(inputColumns)\n" +
				"kMeansResult <- kmeans(frame,number_of_clusters,number_of_Iterations, randomsets, algorithm)\n";
		
		//we're passing a pointer to a callback defined in the DataMiningChannelToR
		public function KMeansClustering(caller:Object, fillingResult:Function = null)
		{
			checkingIfFilled = fillingResult;
			this.algoCaller = caller;
		}
		
		public function doKMeans(_columns:Array,token:Array,_numberOfClusters:Number, _numberOfIterations:Number, _algorithm:String, _randomSets:Number):void
		{
			var inputValues:Array = new Array();
			inputValues.push(_columns);
			inputValues.push(_numberOfClusters);
			inputValues.push(_numberOfIterations);
			inputValues.push(_randomSets);
			var inputNames:Array = ["inputColumns", "number_of_clusters","number_of_Iterations","randomsets"];
			if(_algorithm != null)
			{
				inputValues.push(_algorithm);
				inputNames.push("algorithm");
			}
			// to do: whether to get the entire object back, or separate parameters
			var outputNames:Array = ["kMeansResult$cluster","kMeansResult$centers", "kMeansResult$totss", "kMeansResult$withinss","kMeansResult$tot.withinss","kMeansResult$betweenss","kMeansResult$size"];
			
			var query:AsyncToken = Rservice.runScript(token,inputNames, inputValues,outputNames,kMeansScript,"",false, false, false);
			addAsyncResponder(query,handleRunScriptResult, handleRunScriptFault,token);
		}
		
		
		public function handleRunScriptResult(event:ResultEvent, keys:Array):void
		{
			//Object to stored returned result - Which is array of object{name: , value: }
			var RresultArray:Array = new Array();//this collects only the cluster groupings vector
			var clusterResult:Array = new Array();//this collects all iformation about the cluster object sent from R
			var Robj:Array = event.result as Array;
			//trace('Robj:',ObjectUtil.toString(Robj));
			if (Robj == null)
			{
				reportError("R Servlet did not return an Array of results as expected.");
				return;
			}
			
			//collecting Objects of type RResult(Should Match result object from Java side)
			for (var i:int = 0; i < (event.result).length; i++)
			{
				if (Robj[i] == null)
				{
					trace("WARNING! R Service returned null in results array at index "+i);
					continue;
				}
				var rResult:RResult = new RResult(Robj[i]);
				clusterResult.push(rResult.value);				
			}
			 //we convert only this property of the kmeans clustering object to a column
			 RresultArray.push(Robj[0]);
			
			
			/*TO DO :What do we do with th rest of the object?
			 Entire object
			 this contains all the different metrics of a single Kmeans clustering object*/
			 if(algoCaller is DataMiningChannelToR)
			 {
				 finalResult = new KMeansClusteringResult(clusterResult, keys);
				 if(checkingIfFilled != null )
					 checkingIfFilled(finalResult);
			 }
			 
			 else 
			 {
				 //Objects "(object{name: , value:}" are mapped whose value length that equals Keys length
				 for (var p:int = 0;p < RresultArray.length; p++)
				 {
				 
					 if(RresultArray[p].value is Array)
					 {
					 	if(keys)
						{
					 		if ((RresultArray[p].value).length == keys.length)
							{
								 if (RresultArray[p].value[0] is String)	
								 {
					 				var testStringColumn:StringColumn = Weave.root.requestObject(RresultArray[p].name, StringColumn, false);
									var keyVec:Vector.<IQualifiedKey> = new Vector.<IQualifiedKey>();
					 				var dataVec:Vector.<String> = new Vector.<String>();
									 VectorUtils.copy(keys, keyVec);
									 VectorUtils.copy(Robj[p].value, dataVec);
									 testStringColumn.setRecords(keyVec, dataVec);
									 if (keys.length > 0)
									 testStringColumn.metadata.@keyType = (keys[0] as IQualifiedKey).keyType;
					 					testStringColumn.metadata.@name = RresultArray[p].name;
				 				  }
								 else
								 {
									 var table:Array = [];
									 for (var k:int = 0; k < keys.length; k++)
									 table.push([ (keys[k] as IQualifiedKey).localName, Robj[p].value[k] ]);
									 
									 //testColumn are named after respective Objects Name (i.e) object{name: , value:}
									 var testColumn:CSVColumn = Weave.root.requestObject(RresultArray[p].name, CSVColumn, false);
									 testColumn.keyType.value = keys.length > 0 ? (keys[0] as IQualifiedKey).keyType : null;
									 testColumn.numericMode.value = true;
									 testColumn.data.setSessionState(table);
									 testColumn.title.value = RresultArray[p].name;
								  }
							 }
				 		}								
					 }										
				 }
			 }
			
			
		}
		
		public function handleRunScriptFault(event:FaultEvent, token:Object = null):void
		{
			trace(["fault", token, event.message].join('\n'));
			reportError(event);
		}
		
	}
}