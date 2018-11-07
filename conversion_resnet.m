% �������ݼ���ģ��·��
modelPath='C:\Program Files\MATLAB\R2016b\matconvnet-1.0-beta25\matconvnet-1.0-beta25\data\cifar-resnet\net-sorted.mat';
imdbPath= 'imdb_whiten.mat';

% �������ݼ�
% imdb=load(imdbPath);
trainSet=find(imdb.images.set==1);
testSet=find(imdb.images.set==3);
num_examples=10000;

% ���� CNN ѵ��ģ�ͣ������ģ�ͱ����� deployed ֮���
% load(modelPath);
% net=dagnn.DagNN.loadobj(net);


% -------------------------------------------------------------------------
%                                                         �����㼶��ϵ����ͼ
% -------------------------------------------------------------------------

link=zeros(numel(net.layers),2);

link(1,2)=2;
link(1,1)=1;
for l=2:numel(net.layers)

	if isa(net.layers(l).block,'dagnn.Conv')
		ll=l;
		while true
			i=net.layers(ll).inputIndexes-1;
			if  isa(net.layers(i).block,'dagnn.ReLU')							  
				link(l,1)=i;
				break;
			end
			ll=i;
		end
		link(l,2)=l+1; % ������ relu ����Ϊ scale point


	elseif isa(net.layers(l).block,'dagnn.Sum')
		for i=net.layers(l).inputIndexes-1
			if isa(net.layers(i).block,'dagnn.ReLU')
				link(i,2)=l+1;
				link(i,1)=i;
			elseif isa(net.layers(i).block,'dagnn.Conv') && net.layers(i).block.stride(1)==1
				link(i,2)=l+1;
			elseif isa(net.layers(i).block,'dagnn.Conv') && net.layers(i).block.stride(1)==2
				j=net.layers(i).inputIndexes-1;
				link(j,2)=l+1;
				link(j,1)=j;
				% ������ʹ�� conv scale�����ﲻʹ�� relu scale
				link(i,2)=l+1;
				link(i,1)=j;
			end
		end
	end
end

link(l-1,2)=l-1;


% -------------------------------------------------------------------------
%                                 ǰ���䣬��¼����ֵ����¼ link ��ز㼤��ֵ
% -------------------------------------------------------------------------
for l=nonzeros(unique(link))'
	net.vars(net.layers(l).outputIndexes).precious=true;
end

% �鿴���о����� max activation
% for l=1:numel(net.layers)
%     if isa(net.layers(l).block,'dagnn.Conv')
%         net.vars(net.layers(l).outputIndexes).precious=true;
%     end
% end

% ��ʼǰ���䣬ǰ����ǰ��Ҫ�� DagNN model �ṹ������κ��Զ����Ԫ��
batchSize=100;
epochs=ceil(num_examples/batchSize);

% output ������ֵ����ת������ռ�ù����ڴ�
output=cell(1,numel(net.vars));

net.mode='test';
for epoch=1:10

	batchStart=(epoch-1)*batchSize+1;
	batchEnd=min(epoch*batchSize,num_examples);
	batch=testSet(batchStart:batchEnd);

	im=imdb.images.data(:,:,:,batch);
	label=imdb.images.labels(1,batch);
    inputs={'input',im};
	net.eval(inputs);

    % l �ǲ������output �Ǳ���������Ҳ����ֱ�ӱ�������
	for l=nonzeros(unique(link))'
		output{net.layers(l).outputIndexes}=cat(4,output{net.layers(l).outputIndexes},...
												net.vars(net.layers(l).outputIndexes).value);
    end
    
    % �鿴���о����� max_activation
%     for l=1:numel(net.layers)
%         if isa(net.layers(l).block,'dagnn.Conv')
%             output{net.layers(l).outputIndexes}=cat(4,output{net.layers(l).outputIndexes},...
%                                                     net.vars(net.layers(l).outputIndexes).value);
%         end
%     end

    fprintf('%d epoch forward finised.\n',epoch);
end

% �������������ظ�ֵ net.vars
for i=1:numel(net.vars)
	net.vars(i).value=output{i};
end
clear output;

snn=parse_resconv(net,link,99.99); 
opts.dt 			= 0.001;
opts.duration		= 2.500;
opts.report_every	= 0.010;
opts.threshold		=   1.0;
opts.batch 			= 50001:51000;
% 
[performance,stats]=resconv2snn(snn,imdb,opts);
